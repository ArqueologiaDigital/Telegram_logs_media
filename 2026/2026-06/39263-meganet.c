/***************************************************************************************
 * MegaNet / Telebradesco modem cartridge hardware support
 *
 * 8250-like UART stub mapped at $200000-$20000F.
 * v45.2: same v45.1 behavior, plus focused PC trace in meganet.c for UART TX.
 * v45.1: same v45 NO CARRIER behavior, but with capped/throttled logs.
 * v45: report NO CARRIER/numeric 3 to the ROM when the TCP server closes the socket.
 * v44: actually calls TCP bridge after CONNECT; v43 only defined the helpers.
 * v43: optional TCP bridge to an external MegaNet server after CONNECT.
 * v42: sends a visible welcome/confirmation message after cadastro.
 * v41: handles client #bye# packet as a clean end-of-session and drops carrier.
 * v40: parses client packet frames after login/cadastro and responds reactively.
 * v39: post-login tokens are packet-layer payloads.  FUN_000088EA / FUN_0000884E
 * read from the packet buffer filled by FUN_00009024, not directly from raw UART bytes.
 * After #bemvindo#, FUN_0000884E expects control token table[4] == "ready".
 * On the wire this must be framed as #ready#\r, not raw 0x04.
 * v29: reactive post-login protocol; do not push #id/#message to the ROM.
 *      Wait for the client to send #id/#get cadastro, then answer.
 * v27: fixes v26 state guard: stage 32 must be allowed to queue #bemvindo#.
 * v24: based on v23, but follows the Ghidra state trace: after MAURICIO
 * the ROM waits for ACK (0x06), then performs a small control-byte handshake
 * before it waits for #bemvindo#.  Do not send #id/#message during the login
 * controller; those belong to the next state after login succeeds.
 * v23: based on v22, but treats the third client field as a fixed/idle-terminated
 * profile/name field.  The v22 trace showed the ROM sends MAURICIO without a
 * terminating CR, then waits; v23 queues #bemvindo# after the partial name field
 * becomes idle instead of waiting forever for CR.
 * This module is intended to be built as core/cart_hw/meganet.c.
 *
 * TCP bridge mode:
 *   - Keep local Hayes/UART emulation through CONNECT.
 *   - After CONNECT, try connecting to 127.0.0.1:19777.
 *   - If the TCP server is available, relay online bytes to/from it.
 *   - If connection fails, fall back to the built-in scripted v42 server.
 ****************************************************************************************/

/*
 * Build-time switch.  Set MEGANET_TCP_BRIDGE to 0 to use only the embedded
 * scripted v42 server.  With the default value 1, online traffic after CONNECT
 * is relayed to meganet_server.py on localhost:19777 when that server is running.
 */
#ifndef MEGANET_TCP_BRIDGE
#define MEGANET_TCP_BRIDGE 1
#endif

#define MEGANET_TCP_HOST "127.0.0.1"
#define MEGANET_TCP_PORT 19777
#define MEGANET_TCP_RX_POLL_LIMIT 64

#if MEGANET_TCP_BRIDGE
#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#endif
#endif

#include "shared.h"
#include "meganet.h"
#include <stdio.h>
#include <string.h>

#if defined(__GNUC__) || defined(__clang__)
#define MEGANET_UNUSED __attribute__((unused))
#else
#define MEGANET_UNUSED
#endif

/************************************************************
          MegaNet/Telebradesco modem hardware logger / minimal UART stub
*************************************************************/

/*
  The MegaNet/Telebradesco cartridge ROM accesses an internal modem through an 8250-like UART
  mapped at odd addresses in the cartridge area:

    $200001 = RBR/THR/DLL
    $200003 = IER/DLM
    $200005 = IIR/FCR
    $200007 = LCR
    $200009 = MCR
    $20000B = LSR
    $20000D = MSR

  This first implementation is intentionally small:
    - it logs all register accesses to C:/Temp/meganet/meganet_modem_hw.log
    - it logs bytes written by the ROM to THR
    - it emulates enough UART status bits for the ROM to continue
    - it returns Hayes numeric modem results with CRLF ("0\r\n" for OK, "1\r\n" for CONNECT)
      for basic AT-command tracing.
    - v9 briefly clears LSR THRE/TEMT after each THR write so ROM routines that wait
      for a busy->ready transition do not stall after the first byte.
    - v10 enables modem command echo after the ATH0 reset response has been consumed.
      The registration flow starts sending AT&F&C1V0B0%L3L3 and appears to wait for
      the modem echo after writing the initial 'A' byte.
    - v13 injects a server-side LOGIN prompt after CONNECT. The ROM reaches
      "Aguarda LOGIN" after dial/connect and then only polls LSR, meaning the
      server must speak first.
    - v19 deliberately restores echo of carriage return bytes. The v18 experiment
      that suppressed CR/LF echo regressed before dial, producing AAT+++ and a
      +++/ATH0 abort loop.
*/

#define MEGANET_MODEM_DEBUG          1
#define MEGANET_MODEM_AUTO_RESPONSE  1
#define MEGANET_MODEM_LOG_PATH       "C:/Temp/meganet/meganet_modem_hw.log"
#define MEGANET_MODEM_TX_BIN_PATH    "C:/Temp/meganet/meganet_modem_tx.bin"
#define MEGANET_MODEM_RX_BIN_PATH    "C:/Temp/meganet/meganet_modem_rx.bin"
#define MEGANET_MODEM_PC_TRACE_PATH  "C:/Temp/meganet/meganet_pc_trace.log"

/*
 * v45.2 focused PC trace.
 * This avoids depending on the Musashi header instrumentation path. The trace
 * is emitted from this cartridge module, which is known to be active because
 * meganet_modem_hw.log is being generated. It records only bytes written by
 * the ROM to the UART TX register while connected, enough to identify the PC
 * that sends #id, ATH0, +++, etc.
 */
#ifndef MEGANET_MODEM_PC_TRACE
#define MEGANET_MODEM_PC_TRACE 1
#endif

#ifndef MEGANET_MODEM_PC_TRACE_MAX_BYTES
#define MEGANET_MODEM_PC_TRACE_MAX_BYTES (1UL * 1024UL * 1024UL)
#endif

/*
 * Log controls for normal reverse-engineering runs.
 * The full register trace is useful only for very short captures; when enabled it
 * can make meganet_modem_hw.log grow extremely fast because the ROM polls LSR/MSR
 * continuously.  Default v45.1 behavior keeps high-level events and packet
 * summaries, but suppresses byte-by-byte register accesses.
 */
#ifndef MEGANET_MODEM_LOG_REG_ACCESS
#define MEGANET_MODEM_LOG_REG_ACCESS 0
#endif
#ifndef MEGANET_MODEM_LOG_NONREG_ACCESS
#define MEGANET_MODEM_LOG_NONREG_ACCESS 0
#endif
#ifndef MEGANET_MODEM_LOG_VERBOSE_QUEUE_BYTES
#define MEGANET_MODEM_LOG_VERBOSE_QUEUE_BYTES 0
#endif
#ifndef MEGANET_MODEM_BIN_TRACE
#define MEGANET_MODEM_BIN_TRACE 1
#endif
#ifndef MEGANET_MODEM_LOG_MAX_BYTES
#define MEGANET_MODEM_LOG_MAX_BYTES (2UL * 1024UL * 1024UL)
#endif
#ifndef MEGANET_MODEM_BIN_MAX_BYTES
#define MEGANET_MODEM_BIN_MAX_BYTES (4UL * 1024UL * 1024UL)
#endif

#define MEGANET_MODEM_ADDR_MASK      0xFFFFFF
#define MEGANET_MODEM_BASE           0x200000
#define MEGANET_UART_RBR_THR_DLL     0x200001
#define MEGANET_UART_IER_DLM         0x200003
#define MEGANET_UART_IIR_FCR         0x200005
#define MEGANET_UART_LCR             0x200007
#define MEGANET_UART_MCR             0x200009
#define MEGANET_UART_LSR             0x20000B
#define MEGANET_UART_MSR             0x20000D

#define MEGANET_RX_QUEUE_MASK        0x0FFF
#define MEGANET_AT_BUFFER_SIZE       256
#define MEGANET_CLIENT_PACKET_MAX     512
#define MEGANET_TX_BUSY_POLLS        2
#define MEGANET_SERVER_IDLE_PROMPT_POLLS  120
#define MEGANET_SERVER_POST_ACK_IDLE_POLLS  240
#define MEGANET_PROTO_ACK              0x06
#define MEGANET_PROTO_NAK              0x15
#define MEGANET_PROTO_EOT              0x04
#define MEGANET_PROTO_DLE              0x10

static FILE *meganet_modem_log = NULL;
static FILE *meganet_modem_tx_bin = NULL;
static FILE *meganet_modem_rx_bin = NULL;
#if MEGANET_MODEM_DEBUG && MEGANET_MODEM_PC_TRACE
static FILE *meganet_modem_pc_trace = NULL;
static char meganet_pc_trace_line[512];
static unsigned int meganet_pc_trace_line_len = 0;
#endif

static uint8 meganet_uart_rbr = 0x00;
static uint8 meganet_uart_ier = 0x00;
static uint8 meganet_uart_iir = 0x01;
static uint8 meganet_uart_lcr = 0x00;
static uint8 meganet_uart_mcr = 0x00;
static uint8 meganet_uart_dll = 0x00;
static uint8 meganet_uart_dlm = 0x00;

static uint8 meganet_rx_queue[MEGANET_RX_QUEUE_MASK + 1];
static unsigned int meganet_rx_head = 0;
static unsigned int meganet_rx_tail = 0;

static char meganet_at_buffer[MEGANET_AT_BUFFER_SIZE];
static unsigned int meganet_at_len = 0;
static unsigned int meganet_modem_connected = 0;
static unsigned int meganet_tx_busy_polls = 0;
static unsigned int meganet_echo_enabled = 0;
static unsigned int meganet_echo_enable_when_rx_empty = 0;
static unsigned int meganet_numeric_mode = 0;
static unsigned int meganet_server_stage = 0;
static unsigned int meganet_server_idle_lsr_polls = 0;
static unsigned int meganet_server_control_ack_count = 0;
static char meganet_client_line[MEGANET_AT_BUFFER_SIZE];
static unsigned int meganet_client_line_len = 0;
static uint8 meganet_server_packet_seq = 0;

static unsigned int meganet_client_packet_state = 0;
static unsigned int meganet_client_packet_len = 0;
static unsigned int meganet_client_packet_seq = 0;
static unsigned int meganet_client_packet_pos = 0;
static uint8 meganet_client_packet_payload[MEGANET_CLIENT_PACKET_MAX];
static uint8 meganet_client_packet_ck0 = 0;
static uint8 meganet_client_packet_ck1 = 0;

static void meganet_rx_enqueue_byte(uint8 data);
static void meganet_rx_enqueue_string(const char *s);
static void meganet_modem_enqueue_no_carrier_response(const char *reason);


#if MEGANET_TCP_BRIDGE
#ifdef _WIN32
static SOCKET meganet_tcp_sock = INVALID_SOCKET;
static unsigned int meganet_tcp_wsa_started = 0;
#else
static int meganet_tcp_sock = -1;
#endif
static unsigned int meganet_tcp_connected = 0;
static unsigned int meganet_tcp_bridge_active = 0;
#endif

int meganet_is_cart(void)
{
  if (strstr(rominfo.international, "MEGA NET") || strstr(rominfo.domestic, "MEGA NET"))
  {
    return 1;
  }

  return 0;
}

static uint32 meganet_modem_normalize_address(uint32 address)
{
  /*
    Depending on the 68k memory access path used by Genesis Plus GX, cartridge
    handlers can receive either the full 24-bit CPU address ($200001) or the
    offset inside the mapped 64KB page ($000001).  Normalize both forms so the
    UART decoder works in either case.
  */
  address &= MEGANET_MODEM_ADDR_MASK;

  if (address < 0x10000)
  {
    address |= MEGANET_MODEM_BASE;
  }

  return address;
}

static int meganet_modem_is_reg(uint32 address)
{
  address = meganet_modem_normalize_address(address);

  if ((address >= MEGANET_UART_RBR_THR_DLL) && (address <= MEGANET_UART_MSR) && (address & 1))
  {
    return 1;
  }

  return 0;
}

static FILE *meganet_modem_open_capped(const char *path, unsigned long max_bytes, int binary)
{
  FILE *f = fopen(path, binary ? "ab" : "a");

  if (f)
  {
    long size = 0;

    if (fseek(f, 0, SEEK_END) == 0)
    {
      size = ftell(f);
    }

    if ((size > 0) && ((unsigned long)size >= max_bytes))
    {
      fclose(f);
      f = fopen(path, binary ? "wb" : "w");

      if (f && !binary)
      {
        fprintf(f, "==== MegaNet log rotated/truncated after reaching %lu bytes ====\n", max_bytes);
        fflush(f);
      }
    }
  }

  return f;
}

static void meganet_modem_log_init(void)
{
#if MEGANET_MODEM_DEBUG
  if (!meganet_modem_log)
  {
    meganet_modem_log = meganet_modem_open_capped(MEGANET_MODEM_LOG_PATH, MEGANET_MODEM_LOG_MAX_BYTES, 0);
#if MEGANET_MODEM_BIN_TRACE
    meganet_modem_tx_bin = meganet_modem_open_capped(MEGANET_MODEM_TX_BIN_PATH, MEGANET_MODEM_BIN_MAX_BYTES, 1);
    meganet_modem_rx_bin = meganet_modem_open_capped(MEGANET_MODEM_RX_BIN_PATH, MEGANET_MODEM_BIN_MAX_BYTES, 1);
#endif

    if (meganet_modem_log)
    {
      fprintf(meganet_modem_log, "\n==== MegaNet/Telebradesco modem hardware logger started ====\n");
      fprintf(meganet_modem_log, "UART range: $200001-$20000D\n");
      fprintf(meganet_modem_log, "RBR/THR/DLL=$200001 IER/DLM=$200003 IIR/FCR=$200005 LCR=$200007 MCR=$200009 LSR=$20000B MSR=$20000D\n");
      fprintf(meganet_modem_log, "Address normalization: accepts both full $20000x and page-offset $00000x callbacks\n");
      fprintf(meganet_modem_log, "Mapping mode: bank $20 base is NULL so read/write callbacks are mandatory\n");
      fprintf(meganet_modem_log, "Empty RBR policy: return $00 instead of $FF to avoid open-bus/absent-UART detection\n");
      fprintf(meganet_modem_log, "No-wait reset policy v44: TCP bridge is attempted after CONNECT; fallback scripted v42 server\n");
      fprintf(meganet_modem_log, "TX busy policy v9: LSR THRE/TEMT clear for %u poll(s) after each THR write\n", MEGANET_TX_BUSY_POLLS);
      fprintf(meganet_modem_log, "Log policy v45.2: reg_access=%u nonreg=%u queue_bytes=%u pc_trace=%u max_log=%lu max_bin=%lu\n", MEGANET_MODEM_LOG_REG_ACCESS, MEGANET_MODEM_LOG_NONREG_ACCESS, MEGANET_MODEM_LOG_VERBOSE_QUEUE_BYTES, MEGANET_MODEM_PC_TRACE, (unsigned long)MEGANET_MODEM_LOG_MAX_BYTES, (unsigned long)MEGANET_MODEM_BIN_MAX_BYTES);
      fflush(meganet_modem_log);
    }
  }
#endif
}


static uint32 meganet_modem_trace_current_pc(void)
{
#if defined(M68K_REG_PC)
  return ((uint32)m68k_get_reg(NULL, M68K_REG_PC)) & 0x00ffffff;
#else
  return 0;
#endif
}

static void meganet_modem_pc_trace_init(void)
{
#if MEGANET_MODEM_DEBUG && MEGANET_MODEM_PC_TRACE
  if (!meganet_modem_pc_trace)
  {
    meganet_modem_pc_trace = meganet_modem_open_capped(MEGANET_MODEM_PC_TRACE_PATH, MEGANET_MODEM_PC_TRACE_MAX_BYTES, 0);

    if (!meganet_modem_pc_trace)
    {
      meganet_modem_pc_trace = meganet_modem_open_capped("meganet_pc_trace.log", MEGANET_MODEM_PC_TRACE_MAX_BYTES, 0);
    }

    if (meganet_modem_pc_trace)
    {
      fprintf(meganet_modem_pc_trace, "\n==== MegaNet v45.2 focused UART TX PC trace started ====\n");
#if defined(M68K_REG_PC)
      fprintf(meganet_modem_pc_trace, "PC source: m68k_get_reg(NULL, M68K_REG_PC)\n");
#else
      fprintf(meganet_modem_pc_trace, "PC source: unavailable at compile time; pc=$000000 means M68K_REG_PC was not visible here\n");
#endif
      fprintf(meganet_modem_pc_trace, "Scope: ROM writes to UART THR while connected, before TCP bridge forwarding\n");
      fflush(meganet_modem_pc_trace);
    }
  }
#endif
}

static void meganet_modem_pc_trace_tx_byte(uint8 data)
{
#if MEGANET_MODEM_DEBUG && MEGANET_MODEM_PC_TRACE
  uint32 pc = meganet_modem_trace_current_pc();
  uint8 c = data & 0xff;

  meganet_modem_pc_trace_init();

  if (!meganet_modem_pc_trace)
  {
    return;
  }

  fprintf(
    meganet_modem_pc_trace,
    "TX pc=$%06X data=$%02X ascii=%c stage=%u connected=%u tcp=%u\n",
    pc,
    data & 0xff,
    ((c >= 0x20) && (c <= 0x7e)) ? c : '.',
    meganet_server_stage,
    meganet_modem_connected,
#if MEGANET_TCP_BRIDGE
    meganet_tcp_bridge_active
#else
    0
#endif
  );

  if ((data == 0x0d) || (data == 0x0a))
  {
    meganet_pc_trace_line[meganet_pc_trace_line_len] = 0;
    fprintf(meganet_modem_pc_trace, "LINE_END pc=$%06X text=%s\n", pc, meganet_pc_trace_line);
    meganet_pc_trace_line_len = 0;
  }
  else if (meganet_pc_trace_line_len < (sizeof(meganet_pc_trace_line) - 1))
  {
    meganet_pc_trace_line[meganet_pc_trace_line_len++] = ((c >= 0x20) && (c <= 0x7e)) ? c : '.';
  }

  fflush(meganet_modem_pc_trace);
#endif
}

static void meganet_modem_log_access(const char *op, uint32 address, uint32 data)
{
#if MEGANET_MODEM_DEBUG
  uint8 c = data & 0xff;

#if !MEGANET_MODEM_LOG_REG_ACCESS
  if (!strcmp(op, "R8") || !strcmp(op, "W8"))
  {
    return;
  }
#endif

#if !MEGANET_MODEM_LOG_NONREG_ACCESS
  if (!strcmp(op, "R8_NONREG") || !strcmp(op, "W8_NONREG"))
  {
    return;
  }
#endif

#if !MEGANET_MODEM_LOG_VERBOSE_QUEUE_BYTES
  if (!strcmp(op, "TCP_RX_Q") || !strcmp(op, "SERVER_RX_Q") || !strcmp(op, "CLIENT_TX") || !strcmp(op, "ECHO"))
  {
    return;
  }
#endif

  meganet_modem_log_init();

  if (meganet_modem_log)
  {
    fprintf(
      meganet_modem_log,
      "%s addr=$%06X data=$%02X ascii=%c LCR=$%02X DLL=$%02X DLM=$%02X connected=%u\n",
      op,
      meganet_modem_normalize_address(address) & MEGANET_MODEM_ADDR_MASK,
      data & 0xff,
      ((c >= 0x20) && (c <= 0x7e)) ? c : '.',
      meganet_uart_lcr,
      meganet_uart_dll,
      meganet_uart_dlm,
      meganet_modem_connected
    );

    fflush(meganet_modem_log);
  }
#endif
}

static void meganet_modem_log_text(const char *prefix, const char *text)
{
#if MEGANET_MODEM_DEBUG
  meganet_modem_log_init();

  if (meganet_modem_log)
  {
    fprintf(meganet_modem_log, "%s%s\n", prefix, text);
    fflush(meganet_modem_log);
  }
#endif
}


#if MEGANET_TCP_BRIDGE
static void meganet_tcp_log(const char *message)
{
  meganet_modem_log_text("TCP_BRIDGE ", message ? message : "");
}

static void meganet_tcp_close(void)
{
  if (!meganet_tcp_connected)
  {
    return;
  }

#ifdef _WIN32
  if (meganet_tcp_sock != INVALID_SOCKET)
  {
    closesocket(meganet_tcp_sock);
    meganet_tcp_sock = INVALID_SOCKET;
  }
#else
  if (meganet_tcp_sock >= 0)
  {
    close(meganet_tcp_sock);
    meganet_tcp_sock = -1;
  }
#endif

  meganet_tcp_connected = 0;
  meganet_tcp_bridge_active = 0;
  meganet_tcp_log("closed");
}

static int meganet_tcp_would_block(void)
{
#ifdef _WIN32
  int e = WSAGetLastError();
  return (e == WSAEWOULDBLOCK) || (e == WSAEINPROGRESS) || (e == WSAEALREADY);
#else
  return (errno == EWOULDBLOCK) || (errno == EAGAIN) || (errno == EINPROGRESS);
#endif
}

static int meganet_tcp_set_nonblocking(void)
{
#ifdef _WIN32
  u_long mode = 1;
  return ioctlsocket(meganet_tcp_sock, FIONBIO, &mode) == 0;
#else
  int flags = fcntl(meganet_tcp_sock, F_GETFL, 0);
  if (flags < 0)
  {
    return 0;
  }
  return fcntl(meganet_tcp_sock, F_SETFL, flags | O_NONBLOCK) == 0;
#endif
}

static int meganet_tcp_connect(void)
{
  struct sockaddr_in addr;

  if (meganet_tcp_connected)
  {
    return 1;
  }

#ifdef _WIN32
  if (!meganet_tcp_wsa_started)
  {
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
    {
      meganet_tcp_log("WSAStartup failed; using embedded scripted server");
      return 0;
    }
    meganet_tcp_wsa_started = 1;
  }

  meganet_tcp_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (meganet_tcp_sock == INVALID_SOCKET)
  {
    meganet_tcp_log("socket() failed; using embedded scripted server");
    return 0;
  }
#else
  meganet_tcp_sock = socket(AF_INET, SOCK_STREAM, 0);
  if (meganet_tcp_sock < 0)
  {
    meganet_tcp_log("socket() failed; using embedded scripted server");
    return 0;
  }
#endif

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(MEGANET_TCP_PORT);
  addr.sin_addr.s_addr = inet_addr(MEGANET_TCP_HOST);

  if (connect(meganet_tcp_sock, (struct sockaddr *)&addr, sizeof(addr)) != 0)
  {
#ifdef _WIN32
    closesocket(meganet_tcp_sock);
    meganet_tcp_sock = INVALID_SOCKET;
#else
    close(meganet_tcp_sock);
    meganet_tcp_sock = -1;
#endif
    meganet_tcp_log("connect 127.0.0.1:19777 failed; using embedded scripted server");
    return 0;
  }

  meganet_tcp_connected = 1;
  meganet_tcp_bridge_active = 1;
  meganet_tcp_set_nonblocking();
  meganet_tcp_log("connected to 127.0.0.1:19777; online traffic is now bridged");
  return 1;
}

static void meganet_tcp_send_byte(uint8 data)
{
  int r;

  if (!meganet_tcp_connected)
  {
    return;
  }

#ifdef _WIN32
  r = send(meganet_tcp_sock, (const char *)&data, 1, 0);
#else
  r = (int)send(meganet_tcp_sock, &data, 1, 0);
#endif

  if (r <= 0)
  {
    if (!meganet_tcp_would_block())
    {
      meganet_tcp_log("send failed; closing bridge and reporting carrier drop");
      meganet_tcp_close();
      meganet_modem_connected = 0;
      meganet_modem_enqueue_no_carrier_response("TCP send failed");
    }
  }
}

static void meganet_tcp_poll_rx(void)
{
  unsigned int i;
  uint8 data;
  int r;

  if (!meganet_tcp_connected)
  {
    return;
  }

  for (i = 0; i < MEGANET_TCP_RX_POLL_LIMIT; i++)
  {
#ifdef _WIN32
    r = recv(meganet_tcp_sock, (char *)&data, 1, 0);
#else
    r = (int)recv(meganet_tcp_sock, &data, 1, 0);
#endif

    if (r > 0)
    {
      meganet_rx_enqueue_byte(data);
#if MEGANET_MODEM_DEBUG
      meganet_modem_log_access("TCP_RX_Q", MEGANET_UART_RBR_THR_DLL, data);
#endif
      continue;
    }

    if (r == 0)
    {
      meganet_tcp_log("remote closed; carrier dropped; reporting NO CARRIER to ROM");
      meganet_tcp_close();
      meganet_modem_connected = 0;
      meganet_modem_enqueue_no_carrier_response("TCP remote closed");
      break;
    }

    if (meganet_tcp_would_block())
    {
      break;
    }

    meganet_tcp_log("recv failed; closing bridge and reporting carrier drop");
    meganet_tcp_close();
    meganet_modem_connected = 0;
    meganet_modem_enqueue_no_carrier_response("TCP recv failed");
    break;
  }
}
#endif

static int meganet_rx_available(void)
{
  return (meganet_rx_head != meganet_rx_tail);
}

static void meganet_rx_enqueue_byte(uint8 data)
{
  unsigned int next = (meganet_rx_tail + 1) & MEGANET_RX_QUEUE_MASK;

  if (next == meganet_rx_head)
  {
    meganet_modem_log_text("RX queue full, dropping byte: ", "");
    return;
  }

  meganet_rx_queue[meganet_rx_tail] = data;
  meganet_rx_tail = next;

#if MEGANET_MODEM_DEBUG && MEGANET_MODEM_BIN_TRACE
  if (meganet_modem_rx_bin)
  {
    fputc(data, meganet_modem_rx_bin);
    fflush(meganet_modem_rx_bin);
  }
#endif
}

static uint8 meganet_rx_dequeue_byte(void)
{
  /*
    The MegaNet/Telebradesco ROM appears to probe the UART by reading
    $200001 after programming the divisor/latch registers. Returning $FF
    makes the ROM loop at PC $00980C, which matches an absent/open-bus
    detection path. A present but empty UART should therefore return a
    benign non-$FF value while LSR bit 0 remains clear.
  */
  uint8 data = 0x00;

  if (meganet_rx_available())
  {
    data = meganet_rx_queue[meganet_rx_head];
    meganet_rx_head = (meganet_rx_head + 1) & MEGANET_RX_QUEUE_MASK;

    if (!meganet_rx_available() && meganet_echo_enable_when_rx_empty)
    {
      meganet_echo_enable_when_rx_empty = 0;
      meganet_echo_enabled = 1;
      meganet_modem_log_text("EVENT ", "modem echo enabled after ATH0 response drained");
    }
  }

  meganet_uart_rbr = data;
  return data;
}

static void meganet_rx_enqueue_string(const char *s)
{
  while (*s)
  {
    meganet_rx_enqueue_byte((uint8)*s++);
  }
}

static void meganet_modem_enqueue_no_carrier_response(const char *reason)
{
  if (meganet_numeric_mode)
  {
    meganet_rx_enqueue_string("3\r");
    meganet_modem_log_text("Auto response to ROM: ", "3\\r (NO CARRIER, V0 numeric)");
  }
  else
  {
    meganet_rx_enqueue_string("NO CARRIER\r\n");
    meganet_modem_log_text("Auto response to ROM: ", "NO CARRIER\\r\\n");
  }

  if (reason && *reason)
  {
    meganet_modem_log_text("EVENT ", reason);
  }
}

static void meganet_rx_enqueue_server_string(const char *s)
{
  while (*s)
  {
    uint8 data = (uint8)*s++;
    meganet_rx_enqueue_byte(data);
#if MEGANET_MODEM_DEBUG
    meganet_modem_log_access("SERVER_RX_Q", MEGANET_UART_RBR_THR_DLL, data);
#endif
  }
}


static unsigned int meganet_at_command_length_without_crlf(const char *cmd)
{
  unsigned int len = 0;

  while (cmd[len] && (cmd[len] != '\r') && (cmd[len] != '\n'))
  {
    len++;
  }

  return len;
}

static int meganet_at_command_equals(const char *cmd, const char *expected)
{
  unsigned int i = 0;
  unsigned int cmd_len = meganet_at_command_length_without_crlf(cmd);

  while (expected[i])
  {
    if ((i >= cmd_len) || (cmd[i] != expected[i]))
    {
      return 0;
    }

    i++;
  }

  return (i == cmd_len);
}

static int meganet_at_command_contains_token(const char *cmd, const char *token)
{
  unsigned int cmd_len = meganet_at_command_length_without_crlf(cmd);
  unsigned int token_len = 0;
  unsigned int i, j;

  while (token[token_len])
  {
    token_len++;
  }

  if (!token_len || (token_len > cmd_len))
  {
    return 0;
  }

  for (i = 0; i <= (cmd_len - token_len); i++)
  {
    for (j = 0; j < token_len; j++)
    {
      if (cmd[i + j] != token[j])
      {
        break;
      }
    }

    if (j == token_len)
    {
      return 1;
    }
  }

  return 0;
}


static int meganet_at_command_is_dial(const char *cmd)
{
  unsigned int len = meganet_at_command_length_without_crlf(cmd);
  unsigned int i;

  if ((len < 3) || (cmd[0] != 'A') || (cmd[1] != 'T'))
  {
    return 0;
  }

  /*
    Hayes dial can appear after other command modifiers, for example:
      ATDT1234
      ATDP1234
      ATX3DP,1234567890

    The v11 code only detected commands where D was the first command after AT.
    The registration flow actually sent ATX3DP,<number>, which must be treated
    as a dial attempt and should return CONNECT (numeric 1 in V0 mode), not OK.
  */
  for (i = 2; i < len; i++)
  {
    if (cmd[i] == 'D')
    {
      if ((i + 1) >= len)
      {
        return 1;
      }

      switch (cmd[i + 1])
      {
        case 'T':
        case 'P':
        case ',':
        case 'W':
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
          return 1;

        default:
          break;
      }
    }
  }

  return 0;
}

static int meganet_at_command_is_answer(const char *cmd)
{
  unsigned int len = meganet_at_command_length_without_crlf(cmd);

  return (len >= 3) && (cmd[0] == 'A') && (cmd[1] == 'T') && (cmd[2] == 'A');
}

static void meganet_modem_enqueue_ok_response(const char *reason)
{
  if (meganet_numeric_mode)
  {
    meganet_rx_enqueue_string("0\r");
    meganet_modem_log_text("Auto response to ROM: ", "0\\r (OK, V0 numeric)");
  }
  else
  {
    meganet_rx_enqueue_string("0\r\n");
    meganet_modem_log_text("Auto response to ROM: ", reason ? reason : "0\\r\\n (OK)");
  }
}


static void meganet_modem_enqueue_server_login_prompt(void)
{
  /*
    After a successful dial/connect, the ROM shows "Aguarda LOGIN" and polls
    the UART without sending online payload. The clean prompt that v16 reached
    and consumed is login:\r.
  */
  meganet_rx_enqueue_server_string("login:\r");
  meganet_server_stage = 1;
  meganet_server_idle_lsr_polls = 0;
  meganet_modem_log_text("SERVER prompt queued after CONNECT: ", "login:\\r");
}

static MEGANET_UNUSED void meganet_modem_enqueue_server_password_prompt(const char *why)
{
  if (!meganet_modem_connected || (meganet_server_stage >= 2))
  {
    return;
  }

  meganet_rx_enqueue_server_string("password:\r");
  meganet_server_stage = 2;
  meganet_server_idle_lsr_polls = 0;

  meganet_modem_log_text("SERVER prompt queued: ", why ? why : "password:\\r");
}


static void meganet_modem_log_partial_client_field(const char *prefix)
{
#if MEGANET_MODEM_DEBUG
  meganet_client_line[meganet_client_line_len] = 0;
  meganet_modem_log_text(prefix ? prefix : "CLIENT_FIELD: ", meganet_client_line);
#endif
}


static void meganet_modem_enqueue_server_ack(const char *why)
{
  meganet_rx_enqueue_byte(MEGANET_PROTO_ACK);
#if MEGANET_MODEM_DEBUG
  meganet_modem_log_access("SERVER_CTRL_Q_ACK", MEGANET_UART_RBR_THR_DLL, MEGANET_PROTO_ACK);
  meganet_modem_log_text("SERVER control queued: ", why ? why : "ACK 0x06");
#endif
}

static void meganet_modem_enqueue_server_eot(const char *why)
{
  meganet_rx_enqueue_byte(MEGANET_PROTO_EOT);
#if MEGANET_MODEM_DEBUG
  meganet_modem_log_access("SERVER_CTRL_Q_EOT", MEGANET_UART_RBR_THR_DLL, MEGANET_PROTO_EOT);
  meganet_modem_log_text("SERVER control queued: ", why ? why : "EOT 0x04");
#endif
}

static void meganet_modem_enqueue_server_packet(const uint8 *payload, unsigned int len, const char *why)
{
  unsigned int i;
  uint16 sum = 0;

  /*
    Packet layer used after FUN_00006DEA succeeds.

    Ghidra dump of FUN_000088EA / FUN_0000884E showed these routines read from
    the internal receive buffer at $FFB2F6 through FUN_00008E76/FUN_00008E4E.
    That buffer is filled by FUN_00009024, which parses frames of the form:

      02 LEN SEQ PAYLOAD[LEN] CHECKSUM_HI CHECKSUM_LO

    where CHECKSUM is the 16-bit sum of LEN + SEQ + all payload bytes.
    The ROM acknowledges valid packets with 0x06 and increments its expected
    receive sequence.  Initial receive sequence is 0 after FUN_00008CC4.
  */

  meganet_rx_enqueue_byte(0x02);
  meganet_rx_enqueue_byte((uint8)(len & 0x7f));
  meganet_rx_enqueue_byte(meganet_server_packet_seq);

  sum += (uint8)(len & 0x7f);
  sum += meganet_server_packet_seq;

  for (i = 0; i < len; i++)
  {
    meganet_rx_enqueue_byte(payload[i]);
    sum += payload[i];
  }

  meganet_rx_enqueue_byte((uint8)((sum >> 8) & 0xff));
  meganet_rx_enqueue_byte((uint8)(sum & 0xff));

#if MEGANET_MODEM_DEBUG
  meganet_modem_log_init();
  if (meganet_modem_log)
  {
    fprintf(meganet_modem_log, "SERVER_PACKET_Q seq=%u len=%u checksum=$%04X reason=%s payload=",
            meganet_server_packet_seq, len, sum & 0xffff, why ? why : "");
    for (i = 0; i < len; i++)
    {
      uint8 c = payload[i];
      fputc(((c >= 0x20) && (c <= 0x7e)) ? c : '.', meganet_modem_log);
    }
    fputc('\n', meganet_modem_log);
    fflush(meganet_modem_log);
  }
#endif

  meganet_server_packet_seq++;
}

static void meganet_modem_enqueue_server_packet_string(const char *text, const char *why)
{
  unsigned int len = 0;

  while (text[len])
  {
    len++;
  }

  meganet_modem_enqueue_server_packet((const uint8 *)text, len, why);
}

static MEGANET_UNUSED void meganet_modem_enqueue_server_packet_byte(uint8 data, const char *why)
{
  meganet_modem_enqueue_server_packet(&data, 1, why);
}

static void meganet_modem_enqueue_server_welcome(const char *why)
{
  if (!meganet_modem_connected)
  {
    return;
  }

  /*
    v26 bugfix:
      Handshake stages 30/31/32 are numerically greater than 4, but stage 32 is
      exactly the state that must be allowed to queue #bemvindo# after the third
      ACK is drained.  The old guard `(meganet_server_stage >= 4)` blocked the
      welcome token forever and left the ROM polling LSR=$60.
  */
  if ((meganet_server_stage >= 4) && (meganet_server_stage < 30))
  {
    return;
  }

  /*
    v39: #bemvindo# is packet-layer payload for FUN_000088EA.

    The following call to FUN_0000884E does not expect raw EOT 0x04. It reads a
    control-token packet, accumulates bytes until CR after '#', then compares the
    received token against the table at $0178B4. The login code expects D0 == 4,
    and table[4] is "ready". Therefore the second packet must carry the textual
    token "#ready#\r".
  */
  meganet_modem_enqueue_server_packet_string("#bemvindo#", why ? why : "packet #bemvindo# after DLE ACK idle");
  meganet_modem_enqueue_server_packet_string("#ready#\r", "packet control token #ready#\r for following FUN_0884E");
  meganet_server_stage = 4;
  meganet_server_idle_lsr_polls = 0;

  meganet_modem_log_text("SERVER response queued: ", why ? why : "packet #bemvindo# + packet #ready#\r");
}

static MEGANET_UNUSED void meganet_modem_enqueue_server_id_block(const char *why)
{
  if (!meganet_modem_connected || (meganet_server_stage >= 5))
  {
    return;
  }

  meganet_rx_enqueue_server_string("#id [1] [2] [3]#\r");
  meganet_server_stage = 5;
  meganet_server_idle_lsr_polls = 0;

  meganet_modem_log_text("SERVER response queued: ", why ? why : "#id [1] [2] [3]#\\r after welcome idle");
}

static MEGANET_UNUSED void meganet_modem_enqueue_server_empty_message_block(const char *why)
{
  if (!meganet_modem_connected || (meganet_server_stage >= 6))
  {
    return;
  }

  meganet_rx_enqueue_server_string("#message begin#\rmessage end#\r");
  meganet_modem_enqueue_server_ack("ACK 0x06 after message end#");
  meganet_modem_enqueue_server_eot("EOT 0x04 after message end#");
  meganet_server_stage = 6;
  meganet_server_idle_lsr_polls = 0;

  meganet_modem_log_text("SERVER response queued: ", why ? why : "empty #message# block + ACK/EOT after id idle");
}

static void meganet_modem_enqueue_connect_response(void)
{
  if (meganet_numeric_mode)
  {
    meganet_rx_enqueue_string("1\r");
    meganet_modem_log_text("Auto response to ROM: ", "1\\r (CONNECT, V0 numeric)");
  }
  else
  {
    meganet_rx_enqueue_string("1\r\n");
    meganet_modem_log_text("Auto response to ROM: ", "1\\r\\n (CONNECT)");
  }

  meganet_server_packet_seq = 0;

#if MEGANET_TCP_BRIDGE
  /*
    v44 fix:
      v43 defined the TCP bridge helpers but never called meganet_tcp_connect(),
      so the compiler warned that meganet_tcp_connect() was unused and the
      external Python server never saw a connection.  Try the bridge immediately
      after CONNECT.  If it succeeds, the external server is responsible for
      sending the online login prompt.  If it fails, fall back to the embedded
      scripted server so the already-working flow remains available.
  */
  if (meganet_tcp_connect())
  {
    meganet_server_stage = 100;
    meganet_server_idle_lsr_polls = 0;
    meganet_modem_log_text("TCP_BRIDGE ", "external online server selected after CONNECT; embedded script disabled for this call");
    return;
  }
#endif

  meganet_modem_enqueue_server_login_prompt();
}

static void meganet_modem_handle_at_command(const char *cmd)
{
#if MEGANET_MODEM_DEBUG
  meganet_modem_log_text("AT command from ROM: ", cmd);
#endif

#if MEGANET_MODEM_AUTO_RESPONSE
  /*
    The ROM configures the modem with V0, so Hayes result codes are numeric:
      0 = OK
      1 = CONNECT
      2 = RING
      3 = NO CARRIER
      4 = ERROR
  */
  /*
    Some ROM paths use FUN_000098A8 to send setup/reset commands and do not
    appear to wait for a result code immediately. Enqueuing "0\r" for those
    exact commands leaves stale bytes in RBR that are later consumed after the
    ROM reinitializes the UART. Suppress responses only for the exact no-wait
    reset command observed during initial user registration. Longer
    configuration commands such as AT&F&C1V0B0%L3L3 must still get OK.

    v6 also suppressed ATH0, but the trace showed ATH0 being sent through
    FUN_00009830, which waits for a modem result. Therefore ATH0 must return
    numeric OK to release the ROM from its LSR polling loop. The v7 trace
    showed that after reading "0\r" the ROM kept polling LSR, so v8 returns
    numeric result codes terminated as "0\r\n" / "1\r\n".
  */
  /*
    v11 detail:
      Before the ROM sends AT&F&C1V0B0%L3L3, CRLF for ATH0 is useful because
      the firmware waits for a complete line. Once V0 is programmed, however,
      numeric result codes should be CR-only ("0\r" / "1\r"). Returning "0\r\n"
      after the V0 command left a stale LF in the receive queue; the ROM then
      began the next command while consuming that LF, which desynchronized echo
      handling and produced traces such as "AAT+++".

    v16 detail:
      The v15 trace showed that disabling echo at V0 is too aggressive: after
      receiving the OK for AT&F&C1V0B0%L3L3, the ROM writes the next byte
      (ASCII A) and waits for the modem to echo it before sending the rest of
      the command. Therefore V0 should change only the result-code format, not
      the command echo state.
  */
  if (meganet_at_command_equals(cmd, "AT&F"))
  {
    meganet_modem_connected = 0;
    meganet_modem_log_text("Auto response suppressed for no-wait command: ", "AT&F");
  }
  else if (meganet_at_command_is_dial(cmd) || meganet_at_command_is_answer(cmd))
  {
    if (meganet_at_command_contains_token(cmd, "V0"))
    {
      meganet_numeric_mode = 1;
      meganet_modem_log_text("EVENT ", "numeric V0 result mode enabled by command; echo unchanged");
    }

    if (meganet_at_command_is_dial(cmd))
    {
      meganet_modem_log_text("EVENT ", "dial command detected; reporting CONNECT");
    }
    else
    {
      meganet_modem_log_text("EVENT ", "answer command detected; reporting CONNECT");
    }

    meganet_modem_connected = 1;
    meganet_modem_enqueue_connect_response();
  }
  else if ((cmd[0] == 'A') && (cmd[1] == 'T') && (cmd[2] == 'H'))
  {
#if MEGANET_TCP_BRIDGE
    meganet_tcp_close();
#endif
    meganet_modem_connected = 0;

    /*
      In the initial registration flow, the ROM sends AT&F without waiting,
      then ATH0 with result wait. After consuming the ATH0 OK, it starts the
      longer initialization command and waits for the first echoed byte.
      Enable command echo only after the ATH0 result queue is fully drained,
      so ATH0 itself does not leave stale echo bytes before the OK result.
    */
    meganet_modem_enqueue_ok_response(meganet_numeric_mode ? "0\\r (OK/HANGUP, V0 numeric)" : "0\\r\\n (OK/HANGUP); echo will enable after response drain");
    meganet_echo_enable_when_rx_empty = 1;
  }
  else
  {
    if (strstr(cmd, "E0"))
    {
      meganet_echo_enabled = 0;
      meganet_echo_enable_when_rx_empty = 0;
      meganet_modem_log_text("EVENT ", "modem echo disabled by command");
    }
    else if (strstr(cmd, "E1"))
    {
      meganet_echo_enabled = 1;
      meganet_echo_enable_when_rx_empty = 0;
      meganet_modem_log_text("EVENT ", "modem echo enabled by command");
    }

    if (meganet_at_command_contains_token(cmd, "V0"))
    {
      meganet_numeric_mode = 1;
      meganet_modem_log_text("EVENT ", "numeric V0 result mode enabled by command; echo unchanged");
    }
    else if (meganet_at_command_contains_token(cmd, "V1"))
    {
      meganet_numeric_mode = 0;
      meganet_modem_log_text("EVENT ", "numeric V0 result mode disabled by V1 command");
    }

    meganet_modem_enqueue_ok_response("0\\r\\n (OK)");
  }
#endif
}


static int meganet_client_line_starts_with(const char *prefix)
{
  const char *p = prefix;
  const char *s = meganet_client_line;

  if (!p || !s)
  {
    return 0;
  }

  while (*p)
  {
    if (*s != *p)
    {
      return 0;
    }

    p++;
    s++;
  }

  return 1;
}

static void meganet_modem_handle_client_line(void)
{
  /*
    Important protocol direction correction:
      - #bemvindo# is server -> client after login/profile ACK.
      - #id [1] [2] [3]# is client -> server, generated by FUN_00007fee.
      - #message begin# / message end# are server -> client responses to #id.
      - #get cadastro# is client -> server, generated by FUN_00008210.
    Older versions incorrectly pushed #id/#message as a timed server script.
  */
  if (meganet_client_line_starts_with("#id "))
  {
    meganet_modem_log_text("EVENT ", "client #id request received; queueing empty message block + ACK/EOT");
    meganet_rx_enqueue_server_string("#message begin#\rmessage end#\r");
    meganet_modem_enqueue_server_ack("ACK 0x06 after #id message end#");
    meganet_modem_enqueue_server_eot("EOT 0x04 after #id message end#");
    meganet_server_stage = 40;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_line_starts_with("#senha "))
  {
    meganet_modem_log_text("EVENT ", "client #senha request received; queueing empty message block + EOT");
    meganet_rx_enqueue_server_string("#message begin#\rmessage end#\r");
    meganet_modem_enqueue_server_eot("EOT 0x04 after #senha message end#");
    meganet_server_stage = 41;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_line_starts_with("#get cadastro#"))
  {
    meganet_modem_log_text("EVENT ", "raw client #get cadastro request received; queueing packet #ready#\r");
    meganet_modem_enqueue_server_packet_string("#ready#\r", "packet #ready#\r after raw client #get cadastro#");
    meganet_server_stage = 50;
    meganet_server_idle_lsr_polls = 0;
    return;
  }
}


static void meganet_client_packet_reset(void)
{
  meganet_client_packet_state = 0;
  meganet_client_packet_len = 0;
  meganet_client_packet_seq = 0;
  meganet_client_packet_pos = 0;
  meganet_client_packet_ck0 = 0;
  meganet_client_packet_ck1 = 0;
}

static int meganet_client_packet_starts_with(const char *prefix)
{
  unsigned int i = 0;

  if (!prefix)
  {
    return 0;
  }

  while (prefix[i])
  {
    if (i >= meganet_client_packet_len)
    {
      return 0;
    }

    if (meganet_client_packet_payload[i] != (uint8)prefix[i])
    {
      return 0;
    }

    i++;
  }

  return 1;
}

static void meganet_modem_log_client_packet(const char *prefix)
{
#if MEGANET_MODEM_DEBUG
  unsigned int i;

  meganet_modem_log_init();
  if (meganet_modem_log)
  {
    fprintf(meganet_modem_log, "%sseq=%u len=%u checksum_bytes=$%02X%02X payload=",
            prefix ? prefix : "CLIENT_PACKET: ",
            meganet_client_packet_seq,
            meganet_client_packet_len,
            meganet_client_packet_ck0,
            meganet_client_packet_ck1);

    for (i = 0; i < meganet_client_packet_len; i++)
    {
      uint8 c = meganet_client_packet_payload[i];
      fputc(((c >= 0x20) && (c <= 0x7e)) ? c : '.', meganet_modem_log);
    }

    fputc('\n', meganet_modem_log);
    fflush(meganet_modem_log);
  }
#endif
}

static void meganet_modem_handle_client_packet(void)
{
  meganet_modem_log_client_packet("CLIENT_PACKET: ");

  /* ACK the client packet first.  FUN_00008970 waits for this raw ACK. */
  meganet_modem_enqueue_server_ack("ACK 0x06 after client packet frame");

  /*
    FUN_00008210 flow from Ghidra:
      send #get cadastro#\r        -> wait FUN_0000884E == ready
      send #begin cadastro#\r      -> send 0..N cadastro records/#item#
      send #end cadastro#\r        -> wait #message begin#, block, message end#, ready

    Therefore the server must be reactive: acknowledge each client packet and
    only queue the next server packet when the corresponding request arrives.
  */
  if (meganet_client_packet_starts_with("#get cadastro#"))
  {
    meganet_modem_log_text("EVENT ", "client packet #get cadastro# received; queueing packet #ready#\\r");
    meganet_modem_enqueue_server_packet_string("#ready#\r", "packet #ready#\\r after client #get cadastro#");
    meganet_server_stage = 50;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_packet_starts_with("#begin cadastro#"))
  {
    meganet_modem_log_text("EVENT ", "client packet #begin cadastro# received; ACK only");
    meganet_server_stage = 51;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_packet_starts_with("#item#"))
  {
    meganet_modem_log_text("EVENT ", "client packet #item# received; ACK only");
    meganet_server_stage = 52;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_packet_starts_with("#end cadastro#"))
  {
    meganet_modem_log_text("EVENT ", "client packet #end cadastro# received; queueing visible welcome message block + ready");
    meganet_modem_enqueue_server_packet_string("#message begin#\r", "packet #message begin#\\r after client #end cadastro#");
    meganet_modem_enqueue_server_packet_string("BEM-VINDO AO MEGA NET\r", "packet visible message line 1 after cadastro");
    meganet_modem_enqueue_server_packet_string("CADASTRO RECEBIDO COM SUCESSO\r", "packet visible message line 2 after cadastro");
    meganet_modem_enqueue_server_packet_string("OBRIGADO POR SE CADASTRAR\r", "packet visible message line 3 after cadastro");
    meganet_modem_enqueue_server_packet_string("#message end#\r", "packet #message end#\\r after visible cadastro response");
    meganet_modem_enqueue_server_packet_string("#ready#\r", "packet #ready#\\r after visible cadastro message");
    meganet_server_stage = 53;
    meganet_server_idle_lsr_polls = 0;
    return;
  }

  if (meganet_client_packet_starts_with("#bye#"))
  {
    /*
      v40 showed that after the cadastro transfer completes successfully the ROM
      sends a final packet containing "#bye#\r", waits for the raw ACK, and then
      falls back to modem hangup commands (ATH0 / +++).  Treat this as a clean
      server-side session close instead of leaving the UART in connected payload
      mode; otherwise the later ATH0/+++ bytes are logged as CLIENT_TX and can
      look like a protocol failure.
    */
    meganet_modem_log_text("EVENT ", "client packet #bye# received; ACK queued and carrier dropped");
#if MEGANET_TCP_BRIDGE
    meganet_tcp_close();
#endif
    meganet_modem_connected = 0;
    meganet_server_stage = 0;
    meganet_server_idle_lsr_polls = 0;
    meganet_client_line_len = 0;
    meganet_client_line[0] = 0;
    meganet_at_len = 0;
    meganet_at_buffer[0] = 0;
    meganet_echo_enabled = 0;
    meganet_echo_enable_when_rx_empty = 0;
    return;
  }

  meganet_modem_log_text("EVENT ", "client packet payload not specially handled; ACK only");
}

static int meganet_modem_process_client_packet_byte(uint8 data)
{
  /*
    Client frames observed after v39 login success:
      02 LEN SEQ PAYLOAD[LEN] CHECKSUM_LO CHECKSUM_HI 03

    For the current reverse-engineering step we do not enforce the checksum;
    we consume the full frame, log the payload, ACK it, and route known tokens.
  */
  switch (meganet_client_packet_state)
  {
    case 0:
      if (data != 0x02)
      {
        return 0;
      }
      meganet_client_packet_state = 1;
      meganet_client_packet_len = 0;
      meganet_client_packet_seq = 0;
      meganet_client_packet_pos = 0;
      return 1;

    case 1:
      meganet_client_packet_len = data & 0x7f;
      if (meganet_client_packet_len >= MEGANET_CLIENT_PACKET_MAX)
      {
        meganet_modem_log_text("EVENT ", "client packet length too large; parser reset");
        meganet_client_packet_reset();
        return 1;
      }
      meganet_client_packet_state = 2;
      return 1;

    case 2:
      meganet_client_packet_seq = data;
      meganet_client_packet_pos = 0;
      if (meganet_client_packet_len == 0)
      {
        meganet_client_packet_state = 4;
      }
      else
      {
        meganet_client_packet_state = 3;
      }
      return 1;

    case 3:
      meganet_client_packet_payload[meganet_client_packet_pos++] = data;
      if (meganet_client_packet_pos >= meganet_client_packet_len)
      {
        meganet_client_packet_state = 4;
      }
      return 1;

    case 4:
      meganet_client_packet_ck0 = data;
      meganet_client_packet_state = 5;
      return 1;

    case 5:
      meganet_client_packet_ck1 = data;
      meganet_client_packet_state = 6;
      return 1;

    case 6:
      if (data == 0x03)
      {
        meganet_modem_handle_client_packet();
      }
      else
      {
        meganet_modem_log_text("EVENT ", "client packet missing ETX; parser reset after checksum");
      }
      meganet_client_packet_reset();
      return 1;
  }

  meganet_client_packet_reset();
  return 1;
}

static void meganet_modem_tx_byte(uint8 data)
{
#if MEGANET_MODEM_DEBUG && MEGANET_MODEM_BIN_TRACE
  if (meganet_modem_tx_bin)
  {
    fputc(data, meganet_modem_tx_bin);
    fflush(meganet_modem_tx_bin);
  }
#endif

  if (meganet_modem_connected)
  {
    /*
      Connected-mode payload is now accumulated into lines as well as logged
      byte-by-byte.  The v19 trace showed the first client response after
      LOGIN:/PASSWORD: was a single CR, so keep that visible as an empty
      CLIENT_LINE and answer with a small server-side OK to test the next state.
    */
    meganet_server_idle_lsr_polls = 0;
    meganet_modem_log_access("CLIENT_TX", MEGANET_UART_RBR_THR_DLL, data);
    meganet_modem_pc_trace_tx_byte(data);

#if MEGANET_TCP_BRIDGE
    if (meganet_tcp_bridge_active)
    {
      meganet_tcp_send_byte(data);
      return;
    }
#endif

    if ((meganet_server_stage >= 4) && ((meganet_client_packet_state != 0) || (data == 0x02)))
    {
      if (meganet_modem_process_client_packet_byte(data))
      {
        return;
      }
    }

    if ((meganet_server_stage >= 4) && ((data == MEGANET_PROTO_ACK) || (data == MEGANET_PROTO_NAK)))
    {
      meganet_modem_log_text("EVENT ", (data == MEGANET_PROTO_ACK) ? "client raw ACK ignored outside packet" : "client raw NAK ignored outside packet");
      return;
    }

    if ((meganet_server_stage >= 30) && ((data == MEGANET_PROTO_DLE) || (data == 0x00)))
    {
      meganet_server_control_ack_count++;
      meganet_modem_enqueue_server_ack((data == MEGANET_PROTO_DLE) ? "ACK 0x06 after client DLE 0x10" : "ACK 0x06 after client NUL 0x00");

      /*
        v29 proved that an extra ACK before #bemvindo# is wrong for this
        path: FUN_000088ea then consumes 0x06 while it is waiting for the
        literal '#bemvindo#' token.  After the DLE ACK is drained, queue the
        welcome token directly.
      */
      meganet_server_stage = 31;
      meganet_server_idle_lsr_polls = 0;

      return;
    }

    if ((data == 0x0d) || (data == 0x0a))
    {
meganet_client_line[meganet_client_line_len] = 0;
#if MEGANET_MODEM_DEBUG
      meganet_modem_log_text("CLIENT_LINE: ", meganet_client_line);
#endif

      if (meganet_server_stage >= 4)
      {
        meganet_modem_handle_client_line();
      }

      if (meganet_server_stage == 1)
      {
        meganet_server_stage = 2;
        meganet_server_idle_lsr_polls = 0;
        meganet_modem_log_text("EVENT ", "login client line received; waiting for password client line without queuing password prompt");
      }
      else if (meganet_server_stage == 2)
      {
        meganet_server_stage = 3;
        meganet_server_idle_lsr_polls = 0;
        meganet_modem_log_text("EVENT ", "password client line received; waiting for profile/name client line before welcome");
      }
      else if (meganet_server_stage == 3)
      {
        meganet_modem_enqueue_server_ack("ACK 0x06 after profile/name client line");
        meganet_server_stage = 30;
        meganet_server_idle_lsr_polls = 0;
      }

      meganet_client_line_len = 0;
      meganet_client_line[0] = 0;
    }
    else
    {
      if (meganet_client_line_len < (MEGANET_AT_BUFFER_SIZE - 1))
      {
        meganet_client_line[meganet_client_line_len++] = (char)data;
        meganet_client_line[meganet_client_line_len] = 0;
      }
    }

    return;
  }

  if (meganet_echo_enabled)
  {
    meganet_rx_enqueue_byte(data);
#if MEGANET_MODEM_DEBUG
    meganet_modem_log_access("ECHO", MEGANET_UART_RBR_THR_DLL, data);
#endif
  }

  if (data == 0x0d)
  {
    if (meganet_at_len < (MEGANET_AT_BUFFER_SIZE - 1))
    {
      meganet_at_buffer[meganet_at_len++] = '\r';
    }

    meganet_at_buffer[meganet_at_len] = 0;
    meganet_modem_handle_at_command(meganet_at_buffer);
    meganet_at_len = 0;
    meganet_at_buffer[0] = 0;
    return;
  }

  if (data == 0x0a)
  {
    return;
  }

  if (meganet_at_len < (MEGANET_AT_BUFFER_SIZE - 1))
  {
    meganet_at_buffer[meganet_at_len++] = (char)data;
    meganet_at_buffer[meganet_at_len] = 0;
  }
}

static uint8 meganet_uart_lsr(void)
{
  uint8 lsr = 0x00;

#if MEGANET_TCP_BRIDGE
  if (meganet_tcp_bridge_active)
  {
    meganet_tcp_poll_rx();
  }
#endif

  /*
    A real 8250-compatible UART does not keep THRE/TEMT permanently asserted
    while the CPU is feeding bytes into THR. Some ROM code appears to wait for
    a short not-ready -> ready transition after writing a byte. If we report
    $60 forever, that path can stall after the first byte of the next command.
  */
  if (meganet_tx_busy_polls)
  {
    meganet_tx_busy_polls--;
  }
  else
  {
    lsr |= 0x60; /* THR empty + transmitter empty */
  }

  if (meganet_rx_available())
  {
    lsr |= 0x01; /* data ready */
  }
  else if (meganet_modem_connected && (meganet_server_stage == 3) && (meganet_client_line_len > 0))
  {
    /*
      The v22 trace showed the ROM sending the configured name (e.g. MAURICIO)
      as an idle-terminated field, without a trailing CR.  Do not wait forever
      for CLIENT_LINE here; after a short quiet period, accept the partial
      field and continue the scripted server flow.
    */
    if (++meganet_server_idle_lsr_polls == MEGANET_SERVER_IDLE_PROMPT_POLLS)
    {
      meganet_modem_log_partial_client_field("CLIENT_FIELD_NO_CR: ");
      meganet_client_line_len = 0;
      meganet_client_line[0] = 0;
      meganet_modem_enqueue_server_ack("ACK 0x06 after idle profile/name field");
      meganet_server_stage = 30;
      meganet_server_idle_lsr_polls = 0;
      lsr |= 0x01;
    }
  }
  else if (meganet_modem_connected && (meganet_server_stage == 30) && (meganet_client_line_len == 0))
  {
    /*
      Stage 30 means the idle-terminated MAURICIO field was ACKed.  Wait for
      the client to send DLE (0x10), handled in meganet_modem_tx_byte().
      Do not send #bemvindo# here yet, because FUN_00006dea is still active.
    */
  }
  else if (meganet_modem_connected && (meganet_server_stage == 31) && (meganet_client_line_len == 0))
  {
    /*
      After the DLE ACK is consumed, expose the welcome token directly.
      The v29 trace showed that adding an extra ACK here leaves 0x06 in
      front of '#bemvindo#', breaking FUN_000088ea's token comparison.
    */
    if (++meganet_server_idle_lsr_polls == MEGANET_SERVER_POST_ACK_IDLE_POLLS)
    {
      meganet_modem_enqueue_server_welcome("#bemvindo# + EOT after DLE ACK idle");
      lsr |= 0x01;
    }
  }
  else if (meganet_modem_connected && (meganet_server_stage == 33) && (meganet_client_line_len == 0))
  {
    /*
      Legacy deferred-EOT path retained only as a safety valve for older stage
      transitions.  v39 normally delivers the following control state as a
      packetized #ready#\r token inside meganet_modem_enqueue_server_welcome().
    */
    if (++meganet_server_idle_lsr_polls == MEGANET_SERVER_POST_ACK_IDLE_POLLS)
    {
      meganet_modem_enqueue_server_eot("deferred EOT 0x04 after #bemvindo# token drain");
      meganet_server_stage = 4;
      meganet_server_idle_lsr_polls = 0;
      lsr |= 0x01;
    }
  }
  else if (meganet_modem_connected && (meganet_server_stage == 4) && (meganet_client_line_len == 0))
  {
    /*
      After #bemvindo# and deferred EOT, do not push #id/#message to the client.
      FUN_00007fee builds and sends #id [1] [2] [3]# itself; we only
      respond when that client line appears in meganet_modem_tx_byte().
    */
  }

  return lsr;
}

static uint8 meganet_uart_msr(void)
{
  uint8 msr = 0x30; /* CTS + DSR */

  if (meganet_modem_connected)
  {
    msr |= 0x80; /* DCD */
  }

  return msr;
}

static uint32 meganet_modem_read_reg(uint32 address)
{
  uint8 data = 0xff;

  address = meganet_modem_normalize_address(address);

  switch (address & MEGANET_MODEM_ADDR_MASK)
  {
    case MEGANET_UART_RBR_THR_DLL:
    {
      if (meganet_uart_lcr & 0x80)
      {
        data = meganet_uart_dll;
      }
      else
      {
        data = meganet_rx_dequeue_byte();
      }
      break;
    }

    case MEGANET_UART_IER_DLM:
    {
      data = (meganet_uart_lcr & 0x80) ? meganet_uart_dlm : meganet_uart_ier;
      break;
    }

    case MEGANET_UART_IIR_FCR:
    {
      data = meganet_uart_iir;
      break;
    }

    case MEGANET_UART_LCR:
    {
      data = meganet_uart_lcr;
      break;
    }

    case MEGANET_UART_MCR:
    {
      data = meganet_uart_mcr;
      break;
    }

    case MEGANET_UART_LSR:
    {
      data = meganet_uart_lsr();
      break;
    }

    case MEGANET_UART_MSR:
    {
      data = meganet_uart_msr();
      break;
    }

    default:
    {
      data = 0xff;
      break;
    }
  }

  meganet_modem_log_access("R8", address, data);
  return data;
}

static void meganet_modem_write_reg(uint32 address, uint32 data)
{
  uint8 value = data & 0xff;

  address = meganet_modem_normalize_address(address);
  meganet_modem_log_access("W8", address, value);

  switch (address & MEGANET_MODEM_ADDR_MASK)
  {
    case MEGANET_UART_RBR_THR_DLL:
    {
      if (meganet_uart_lcr & 0x80)
      {
        meganet_uart_dll = value;
      }
      else
      {
        meganet_tx_busy_polls = MEGANET_TX_BUSY_POLLS;
        meganet_modem_tx_byte(value);
      }
      return;
    }

    case MEGANET_UART_IER_DLM:
    {
      if (meganet_uart_lcr & 0x80)
      {
        meganet_uart_dlm = value;
      }
      else
      {
        meganet_uart_ier = value;
      }
      return;
    }

    case MEGANET_UART_IIR_FCR:
    {
      /* FCR write: clear FIFOs on bits 1/2 if requested. */
      if (value & 0x02)
      {
        meganet_rx_head = meganet_rx_tail = 0;
      }
      return;
    }

    case MEGANET_UART_LCR:
    {
      meganet_uart_lcr = value;
      return;
    }

    case MEGANET_UART_MCR:
    {
      meganet_uart_mcr = value;
      return;
    }

    default:
    {
      return;
    }
  }
}

static uint32 meganet_modem_rom_read8(uint32 address)
{
  address = meganet_modem_normalize_address(address);
  return READ_BYTE(cart.rom, address & cart.mask);
}

static uint32 meganet_modem_rom_read16(uint32 address)
{
  address = meganet_modem_normalize_address(address);
  return *(uint16 *)(cart.rom + (address & cart.mask));
}

static uint32 meganet_modem_r8(uint32 address)
{
  uint32 norm = meganet_modem_normalize_address(address);

  if (meganet_modem_is_reg(norm))
  {
    return meganet_modem_read_reg(norm);
  }

#if MEGANET_MODEM_DEBUG
  /* Keep a small trace of nearby non-register accesses to validate handler addressing. */
  if ((norm >= MEGANET_MODEM_BASE) && (norm <= (MEGANET_MODEM_BASE + 0x0010)))
  {
    meganet_modem_log_access("R8_NONREG", norm, meganet_modem_rom_read8(norm));
  }
#endif

  return meganet_modem_rom_read8(norm);
}

static uint32 meganet_modem_r16(uint32 address)
{
  if (meganet_modem_is_reg(address) || meganet_modem_is_reg(address + 1))
  {
    uint32 data = (meganet_modem_r8(address) << 8) | meganet_modem_r8(address + 1);
    return data;
  }

  return meganet_modem_rom_read16(address);
}

static void meganet_modem_w8(uint32 address, uint32 data)
{
  uint32 norm = meganet_modem_normalize_address(address);

  if (meganet_modem_is_reg(norm))
  {
    meganet_modem_write_reg(norm, data);
    return;
  }

#if MEGANET_MODEM_DEBUG
  if ((norm >= MEGANET_MODEM_BASE) && (norm <= (MEGANET_MODEM_BASE + 0x0010)))
  {
    meganet_modem_log_access("W8_NONREG", norm, data);
  }
#endif

  m68k_unused_8_w(norm, data);
}

static void meganet_modem_w16(uint32 address, uint32 data)
{
  if (meganet_modem_is_reg(address) || meganet_modem_is_reg(address + 1))
  {
    meganet_modem_w8(address, data >> 8);
    meganet_modem_w8(address + 1, data & 0xff);
    return;
  }

  m68k_unused_16_w(address, data);
}

void meganet_modem_reset(void)
{
  meganet_uart_rbr = 0x00;
  meganet_uart_ier = 0x00;
  meganet_uart_iir = 0x01;
  meganet_uart_lcr = 0x00;
  meganet_uart_mcr = 0x00;
  meganet_uart_dll = 0x00;
  meganet_uart_dlm = 0x00;

  meganet_rx_head = 0;
  meganet_rx_tail = 0;
  meganet_at_len = 0;
  meganet_at_buffer[0] = 0;
  meganet_modem_connected = 0;
  meganet_tx_busy_polls = 0;
  meganet_echo_enabled = 0;
  meganet_echo_enable_when_rx_empty = 0;
  meganet_numeric_mode = 0;
  meganet_server_stage = 0;
  meganet_server_idle_lsr_polls = 0;
  meganet_client_line_len = 0;
  meganet_client_line[0] = 0;
  meganet_server_packet_seq = 0;
  meganet_client_packet_reset();

#if MEGANET_TCP_BRIDGE
  meganet_tcp_close();
#endif

  meganet_modem_log_init();
  meganet_modem_log_text("EVENT ", "meganet_modem_reset()");
}

void meganet_modem_install(void)
{
  if (!meganet_is_cart())
  {
    return;
  }

  meganet_modem_reset();

  /*
    $200000-$20FFFF normally points to a ROM mirror for this 256KB cartridge.
    Replace only the block handler. Non-UART addresses still read from the ROM
    mirror through meganet_modem_rom_read8/read16().
  */
  /*
    Force callback path for bank $20. Some 68k memory access paths can use
    memory_map[].base as a fast direct path and bypass custom handlers when
    base is non-NULL.  The MegaNet/Telebradesco hardware needs callbacks for
    both reads and writes, so keep base NULL and let meganet_modem_r8/r16 return
    ROM mirror data for non-UART addresses.
  */
  m68k.memory_map[0x20].base    = NULL;
  m68k.memory_map[0x20].read8   = meganet_modem_r8;
  m68k.memory_map[0x20].read16  = meganet_modem_r16;
  m68k.memory_map[0x20].write8  = meganet_modem_w8;
  m68k.memory_map[0x20].write16 = meganet_modem_w16;

  zbank_memory_map[0x20].read   = meganet_modem_r8;
  zbank_memory_map[0x20].write  = meganet_modem_w8;

  meganet_modem_log_text("EVENT ", "MegaNet modem handler installed at $200000-$20FFFF with base=NULL");
}

/*
  Low-level CPU bypass entry points.

  Some Genesis Plus GX cart mapper paths can overwrite memory_map[0x20] after
  meganet_modem_install().  These wrappers let the 68k memory core dispatch
  $200001-$20000D directly to this UART model as a diagnostic/compatibility path.
*/
int meganet_modem_cpu_handles(unsigned int address)
{
  if (!meganet_is_cart())
  {
    return 0;
  }

  return meganet_modem_is_reg((uint32)address);
}

unsigned int meganet_modem_cpu_read_8(unsigned int address)
{
  return meganet_modem_r8((uint32)address) & 0xff;
}

unsigned int meganet_modem_cpu_read_16(unsigned int address)
{
  return meganet_modem_r16((uint32)address) & 0xffff;
}

void meganet_modem_cpu_write_8(unsigned int address, unsigned int value)
{
  meganet_modem_w8((uint32)address, (uint32)value);
}

void meganet_modem_cpu_write_16(unsigned int address, unsigned int value)
{
  meganet_modem_w16((uint32)address, (uint32)value);
}

