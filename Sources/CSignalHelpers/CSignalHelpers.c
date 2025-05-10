#include "CSignalHelpers.h" // Should be relative to include path, or <CSignalHelpers.h> if system path
#include <unistd.h> // For write, fsync
#include <string.h> // For strlen, strcpy
#include <stdint.h> // For uint64_t
#include <time.h>    // For time_t
// #include <stdio.h>  // For snprintf - avoid for now for max safety

// Super minimal, unsafe integer to string for positive numbers and zero.
// Writes to buffer, returns pointer to end of written string (null terminator).
// Ensure buffer is large enough! (e.g., 12 chars for 32-bit int + sign + null).
static char* minimal_itoa_for_signals(int32_t val, char* buf, int buf_size) {
    if (buf_size < 2) return buf; // Need space for at least '0' and null

    char* start_buf = buf;

    if (val == 0) {
        *buf++ = '0';
        *buf = '\0';
        return buf;
    }
    
    // Note: Handling INT32_MIN (-2147483648) safely with negation needs care.
    // This simple version might have issues if val is INT32_MIN.
    // For signal numbers (small positive), it's usually fine.
    if (val < 0) {
        if (buf_size < 3) return start_buf; // Need space for '-', digit, null
        *buf++ = '-';
        val = -val; 
        buf_size--;
    }
    
    char* p = buf;
    char* p_end = buf + buf_size -1; // Leave space for null terminator

    while (val > 0 && p < p_end) {
        *p++ = (char)((val % 10) + '0');
        val /= 10;
    }
    
    if (p == buf && p < p_end) { // Value was 0 after potential negation, or couldn't write any digit
        *p++ = '0';
    }
    *p = '\0'; // Null terminate
    
    // Reverse the string (digits part)
    char* p1 = buf;
    char* p2 = p - 1;
    while(p1 < p2) {
        char tmp = *p1;
        *p1++ = *p2;
        *p2-- = tmp;
    }
    return p; // Pointer to the null terminator
}

// Integer to ASCII (decimal) - writes to buf, returns ptr to null terminator.
// Does not handle INT_MIN for signed types correctly if val = TYPE_MIN, but ok for positive signals.
static char* simple_itoa(int32_t val, char* buf, int buf_len) {
    char* p = buf + buf_len -1; // Start from end
    *p-- = '\0'; // Null terminator
    if (val == 0 && p > buf) { *p-- = '0'; return p + 1; }
    int sign = (val < 0);
    if (sign) val = -val;
    while(val > 0 && p >= buf) {
        *p-- = (char)((val % 10) + '0');
        val /= 10;
    }
    if (sign && p >= buf) *p-- = '-';
    return p + 1;
}

// Unsigned long long to ASCII (decimal) - writes to buf, returns ptr to null terminator.
static char* simple_ulltoa(uint64_t val, char* buf, int buf_len) {
    char* p = buf + buf_len -1;
    *p-- = '\0';
    if (val == 0 && p > buf) { *p-- = '0'; return p + 1; }
    while(val > 0 && p >= buf) {
        *p-- = (char)((val % 10) + '0');
        val /= 10;
    }
    return p + 1;
}

// Pointer to Hex ASCII "0x..." - writes to buf, returns ptr to null terminator.
static char* simple_ptr_to_hex(const void* ptr_val, char* buf, int buf_len) {
    uintptr_t val = (uintptr_t)ptr_val;
    char* p = buf + buf_len - 1;
    *p-- = '\0';
    const char* hex_chars = "0123456789abcdef";
    if (val == 0 && p > buf) { *p-- = '0'; /* then add 0x below */ }
    while(val > 0 && p >= buf) {
        *p-- = hex_chars[val & 0xF];
        val >>= 4;
    }
    if (p > buf) *p-- = 'x';
    if (p >= buf) *p-- = '0';
    return p + 1;
}

// Helper to write a string literal safely
static int write_literal(int fd, const char* str) {
    return write(fd, str, strlen(str));
}

// Helper to write a formatted number (using our simple converters)
static int write_int32_val(int fd, int32_t val) {
    char num_buf[12]; // Max 11 chars for -2147483648 + null
    char* str_val = simple_itoa(val, num_buf, sizeof(num_buf));
    return write(fd, str_val, strlen(str_val));
}

static int write_uint64_val(int fd, uint64_t val) {
    char num_buf[21]; // Max 20 chars for uint64_max + null
    char* str_val = simple_ulltoa(val, num_buf, sizeof(num_buf));
    return write(fd, str_val, strlen(str_val));
}

static int write_ptr_val(int fd, const void* val) {
    char ptr_buf[sizeof(void*) * 2 + 3]; // "0x" + hex_digits + null
    char* str_val = simple_ptr_to_hex(val, ptr_buf, sizeof(ptr_buf));
    return write(fd, str_val, strlen(str_val));
}

int write_minimal_crash_info_c(int fd, 
                               int32_t signal_num, 
                               time_t timestamp, 
                               uint64_t thread_id, 
                               const void** frames,
                               int frame_count) {
    if (fd < 0) return -1;
    int total_written = 0;
    int res;

    res = write_literal(fd, "Signal: "); if (res > 0) total_written += res;
    res = write_int32_val(fd, signal_num); if (res > 0) total_written += res;
    res = write_literal(fd, "\nTimestamp: "); if (res > 0) total_written += res;
    res = write_int32_val(fd, (int32_t)timestamp); /* time_t can be 32 or 64 bit, cast for simple_itoa */ if (res > 0) total_written += res;
    res = write_literal(fd, "\nThreadID: "); if (res > 0) total_written += res;
    res = write_uint64_val(fd, thread_id); if (res > 0) total_written += res;
    res = write_literal(fd, "\nFrames_count: "); if (res > 0) total_written += res;
    res = write_int32_val(fd, (int32_t)frame_count); if (res > 0) total_written += res;
    res = write_literal(fd, "\nFrames (raw addresses):\n"); if (res > 0) total_written += res;

    for (int i = 0; i < frame_count; ++i) {
        if (frames[i] != NULL) {
            res = write_literal(fd, "  "); if (res > 0) total_written += res;
            res = write_ptr_val(fd, frames[i]); if (res > 0) total_written += res;
            res = write_literal(fd, "\n"); if (res > 0) total_written += res;
        } else {
            res = write_literal(fd, "  0x0 (nil)\n"); if (res > 0) total_written += res;
        }
        // Basic check to prevent runaway loop if writes fail badly and don't advance
        if (total_written > 4000) break; // Safety break, buffer is 4096 in Swift side
    }
    
    res = write_literal(fd, "--- C Minimal Report End ---\n"); if (res > 0) total_written += res;
    
    fsync(fd);
    return total_written > 0 ? total_written : -1; 
} 