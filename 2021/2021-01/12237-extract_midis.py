import struct

with open('vmp3700.u1', 'rb') as f:
	file_buffer = f.read()

index = 0
file_index = 1
while True:
	try:
		index = file_buffer.index(b'MThd', index)
		(header_length,) = struct.unpack_from('>I', file_buffer, index+4)
		if (header_length > 6):
			index += 4
			continue
		(num_tracks,) = struct.unpack_from('>H', file_buffer, index+10)
		print(num_tracks)
		tracks_length = 0
		for i in range(num_tracks):
			track_offset = index+8+header_length+tracks_length
			(track_length,) = struct.unpack_from('>I', file_buffer, track_offset+4)
			tracks_length += 8 + track_length
			print(file_buffer[track_offset:track_offset+4])
		midi_buffer = file_buffer[index:(index+8+header_length+tracks_length)]
		with open(f"vmp3700_{file_index}.mid",'wb') as f:
			f.write(midi_buffer)
		file_index += 1
		index += 4
	except ValueError:
		break