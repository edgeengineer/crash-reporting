#ifndef C_SIGNAL_HELPERS_H
#define C_SIGNAL_HELPERS_H

#include <stdint.h> // For int32_t, uint64_t
#include <time.h>   // For time_t

// Writes a minimal text representation of the crash info to the given file descriptor.
// Parameters:
//   fd: The file descriptor to write to.
//   signal_num: The signal number.
//   timestamp: The raw time_t timestamp of the crash.
//   thread_id: The ID of the crashing thread.
//   frames: Array of raw stack frame addresses (void*).
//   frame_count: Number of frames in the addresses array.
// Returns bytes written, or -1 on error.
int write_minimal_crash_info_c(int fd, 
                               int32_t signal_num, 
                               time_t timestamp, 
                               uint64_t thread_id, 
                               const void** frames, // Changed to const void** for broader compatibility
                               int frame_count);

#endif // C_SIGNAL_HELPERS_H 