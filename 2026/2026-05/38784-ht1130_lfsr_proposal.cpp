// =============================================================================
//  Proposed LFSR improvement for MAME PR #15350 (Holtek HT1130 sound)
//
//  This is a loose, standalone proposal file -- NOT a patch against the MAME
//  tree.  It shows how to replace the hard-coded `ht1130_lfsr2div[128]` table
//  (copied verbatim from BrickEmuPy) with code that derives the same values
//  from the LFSR algorithm, as requested in the PR review discussion.
//
//  Reverse-engineering summary
//  ---------------------------
//  A melody note byte stores a 7-bit *LFSR state*.  The PR's `div` value is
//  simply that state's *position* within the LFSR's maximal-length sequence.
//
//  The sequence is produced by a 7-bit Fibonacci LFSR:
//      * shifts left
//      * 7-bit wide (mask 0x7f)
//      * feedback bit = bit6 XOR bit0
//      * seed = 0x40  (this state has position/divisor 1)
//
//  recurrence:
//      state = ((state << 1) | (((state >> 6) ^ state) & 1)) & 0x7f
//
//  Verified against the published table at positions 1..13 and 127:
//      div[0x40]=1  div[0x01]=2  div[0x03]=3  div[0x07]=4  div[0x0f]=5
//      div[0x1f]=6  div[0x3f]=7  div[0x7f]=8  div[0x7e]=9  div[0x7d]=10
//      div[0x7a]=11 div[0x75]=12 div[0x6a]=13 ... div[0x20]=127
//
//  div[0] stays 0: the all-zero state is never reached by an XOR-feedback
//  LFSR, and a note value of 0 already means "silent" (special-cased in
//  sound_stream_update before the lookup ever happens).
// =============================================================================


// -----------------------------------------------------------------------------
//  Option A (recommended): generate the table once at device_start().
//
//  Keeps the existing O(1) `m_lfsr2div[note & 0x7f]` lookup, so the only change
//  to sound_stream_update() is `ht1130_lfsr2div[...]` -> `m_lfsr2div[...]`.
//  The 128-byte member array replaces the 128-byte static const array, and the
//  magic numbers are gone -- the table is now self-documenting.
// -----------------------------------------------------------------------------

// --- in ht1130.h, inside the device class ------------------------------------
//
//      // sound: LFSR-state -> frequency-divisor lookup, built at start
//      u8  m_lfsr2div[128];
//
//      void build_lfsr_div_table();
//
// -----------------------------------------------------------------------------

// --- in ht1130.cpp -----------------------------------------------------------

void ht1130_device::build_lfsr_div_table()
{
	// The HT1130 melody generator uses a 7-bit Fibonacci LFSR as its
	// programmable frequency divider.  A note byte holds an LFSR state; the
	// audible divisor is that state's index within the LFSR sequence.
	std::fill(std::begin(m_lfsr2div), std::end(m_lfsr2div), 0);

	u8 state = 0x40; // sequence seed: this state has divisor 1
	for (unsigned pos = 1; pos <= 127; pos++)
	{
		m_lfsr2div[state] = u8(pos);

		// advance 7-bit LFSR: shift left, feed in bit6 XOR bit0
		const u8 feedback = ((state >> 6) ^ state) & 1;
		state = u8(((state << 1) | feedback) & 0x7f);
	}

	// m_lfsr2div[0] intentionally left 0: the all-zero LFSR state is
	// unreachable, and note value 0 is handled as silence before lookup.
}

// Call build_lfsr_div_table() from device_start(), e.g. next to the other
// sound-state initialisation, before save_item() registration.  Because the
// table is deterministic it does NOT need to be save-stated.


// -----------------------------------------------------------------------------
//  Option B: compute the divisor on demand, with no table at all.
//
//  sound_stream_update() needs only one note's divisor per call (per audio
//  buffer, not per sample), so the linear scan is negligible.  Use this if you
//  prefer to drop the array entirely.
// -----------------------------------------------------------------------------

u32 ht1130_device::lfsr_note_to_divisor(u8 note) const
{
	note &= 0x7f;
	if (note == 0)
		return 0; // silent note / unreachable all-zero LFSR state

	u8 state = 0x40; // LFSR sequence seed (divisor 1)
	for (u32 pos = 1; pos <= 127; pos++)
	{
		if (state == note)
			return pos;
		state = u8(((state << 1) | (((state >> 6) ^ state) & 1)) & 0x7f);
	}
	return 0; // unreachable for any valid 7-bit state
}


// -----------------------------------------------------------------------------
//  Resulting change in sound_stream_update()
// -----------------------------------------------------------------------------
//
//  Before (PR as submitted):
//      u32 div = ht1130_lfsr2div[note & 0x7f];
//
//  After, Option A:
//      u32 div = m_lfsr2div[note & 0x7f];
//
//  After, Option B:
//      u32 div = lfsr_note_to_divisor(note);
//
//  Everything downstream is unchanged:
//      u32 period = clock() / m_sound_freq_div / div / 2;
//
//  (Guard against div == 0 if it isn't already guaranteed; with the existing
//  `note == 0` early-out above this point, div is always >= 1 here.)
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
//  Note on the 15-bit noise generator
// -----------------------------------------------------------------------------
//
//  The noise path is already algorithmic and needs no change -- it is itself
//  a Fibonacci LFSR (15-bit, taps bit14 ^ bit13, shifting left):
//
//      if (noise)
//          m_sound_rand = (m_sound_rand << 1)
//                       | (((m_sound_rand >> 14) ^ (m_sound_rand >> 13)) & 1);
//
//  Two optional tidy-ups for consistency / correctness:
//    * mask it to 15 bits so it cannot drift into unused high bits:
//          m_sound_rand = ((m_sound_rand << 1)
//                       | (((m_sound_rand >> 14) ^ (m_sound_rand >> 13)) & 1))
//                       & 0x7fff;
//    * ensure m_sound_rand is seeded non-zero at reset (an all-zero state is
//      a fixed point for XOR feedback and would produce silence-as-noise).
// -----------------------------------------------------------------------------
