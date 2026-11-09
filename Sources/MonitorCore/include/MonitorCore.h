#ifndef MONITOR_CORE_H
#define MONITOR_CORE_H
#include <stdint.h>
#include <stddef.h>

typedef struct {
    int pid, ppid;
    unsigned int uid;
    char name[256];
    char path[4096];
    uint64_t resident, virtual_size, cpu_ns, read_bytes, write_bytes, start_time;
    int threads, io_available;
} MMProcess;
typedef struct { uint64_t user, system, idle, nice; } MMCPU;
typedef struct { uint64_t total, free, active, inactive, wired, compressed, swap_total, swap_used; } MMMemory;
typedef struct { uint64_t received, sent; } MMNetwork;
typedef struct { uint64_t read_bytes, write_bytes; int available; } MMDiskIO;
typedef struct { int gpu_available, gpu_percent, battery_available, cycle_count; int64_t design_capacity, max_capacity; } MMHardware;
size_t mm_processes(MMProcess **out);
void mm_free(void *ptr);
int mm_process_matches(int pid, uint64_t start_time);
int mm_process_arguments(int pid, uint64_t start_time, char *out, size_t out_size);
int mm_cpu(MMCPU *out);
size_t mm_cpu_cores(MMCPU **out);
int mm_memory(MMMemory *out);
int mm_network(MMNetwork *out);
void mm_hardware(MMHardware *out);
void mm_disk_io(MMDiskIO *out);
#endif
