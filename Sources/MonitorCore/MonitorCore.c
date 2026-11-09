#include "MonitorCore.h"
#include <libproc.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <sys/proc_info.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/resource.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <stdlib.h>
#include <string.h>

size_t mm_processes(MMProcess **out) {
    *out = NULL;
    int bytes = proc_listallpids(NULL, 0);
    if (bytes <= 0) return 0;
    // proc_listallpids returns a count, not a byte size.
    int capacity = bytes + 128;
    pid_t *pids = calloc((size_t)capacity, sizeof(pid_t));
    if (!pids) return 0;
    int count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
    if (count < 0) { free(pids); return 0; }
    if (count > capacity) count = capacity;
    MMProcess *result = calloc((size_t)count, sizeof(MMProcess));
    if (!result) { free(pids); return 0; }
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0) { timebase.numer = 1; timebase.denom = 1; }
    size_t used = 0;
    for (int i = 0; i < count; i++) {
        pid_t pid = pids[i];
        if (pid <= 0) continue;
        struct proc_taskallinfo info;
        memset(&info, 0, sizeof(info));
        if (proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, sizeof(info)) != sizeof(info)) continue;
        MMProcess *p = &result[used++];
        p->start_time = (uint64_t)info.pbsd.pbi_start_tvsec * 1000000 + info.pbsd.pbi_start_tvusec;
        p->pid = pid; p->ppid = info.pbsd.pbi_ppid; p->uid = info.pbsd.pbi_uid;
        p->resident = info.ptinfo.pti_resident_size; p->virtual_size = info.ptinfo.pti_virtual_size;
        p->cpu_ns = (uint64_t)(((__uint128_t)info.ptinfo.pti_total_user + info.ptinfo.pti_total_system) * timebase.numer / timebase.denom);
        p->threads = info.ptinfo.pti_threadnum;
        proc_name(pid, p->name, sizeof(p->name));
        if (!p->name[0]) strlcpy(p->name, info.pbsd.pbi_comm, sizeof(p->name));
        proc_pidpath(pid, p->path, sizeof(p->path));
        struct rusage_info_v2 usage;
        memset(&usage, 0, sizeof(usage));
        if (proc_pid_rusage(pid, RUSAGE_INFO_V2, (rusage_info_t *)&usage) == 0) {
            p->io_available = 1;
            p->read_bytes = usage.ri_diskio_bytesread; p->write_bytes = usage.ri_diskio_byteswritten;
        }
    }
    free(pids); *out = result; return used;
}
void mm_free(void *ptr) { free(ptr); }
int mm_process_matches(int pid, uint64_t start_time) {
    struct proc_bsdinfo info;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info)) return 0;
    return (uint64_t)info.pbi_start_tvsec * 1000000 + info.pbi_start_tvusec == start_time;
}
int mm_process_arguments(int pid, uint64_t start_time, char *out, size_t out_size) {
    if (!out || out_size == 0 || !mm_process_matches(pid, start_time)) return 0;
    out[0] = 0;
    int mib[] = { CTL_KERN, KERN_PROCARGS2, pid };
    size_t length = 0;
    if (sysctl(mib, 3, NULL, &length, NULL, 0) != 0 || length < sizeof(int) || length > 1024 * 1024) return 0;
    char *buffer = malloc(length);
    if (!buffer) return 0;
    int ok = 0;
    if (sysctl(mib, 3, buffer, &length, NULL, 0) == 0 && length >= sizeof(int) && mm_process_matches(pid, start_time)) {
        int argc = 0; memcpy(&argc, buffer, sizeof(argc));
        char *cursor = buffer + sizeof(argc), *end = buffer + length;
        while (cursor < end && *cursor) cursor++;
        while (cursor < end && !*cursor) cursor++;
        size_t used = 0;
        for (int i = 0; i < argc && cursor < end && *cursor; i++) {
            size_t size = strnlen(cursor, (size_t)(end - cursor));
            if (cursor + size >= end) break;
            if (i && used + 1 < out_size) out[used++] = ' ';
            size_t copy = size < out_size - used - 1 ? size : out_size - used - 1;
            memcpy(out + used, cursor, copy); used += copy; out[used] = 0;
            if (copy != size) break;
            cursor += size + 1;
        }
        ok = used > 0;
    }
    free(buffer); return ok;
}
int mm_cpu(MMCPU *out) {
    host_cpu_load_info_data_t info; mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count) != KERN_SUCCESS) return 0;
    out->user = info.cpu_ticks[CPU_STATE_USER]; out->system = info.cpu_ticks[CPU_STATE_SYSTEM];
    out->idle = info.cpu_ticks[CPU_STATE_IDLE]; out->nice = info.cpu_ticks[CPU_STATE_NICE]; return 1;
}
size_t mm_cpu_cores(MMCPU **out) {
    *out = NULL; natural_t cores = 0; processor_info_array_t info = NULL; mach_msg_type_number_t count = 0;
    if (host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cores, &info, &count) != KERN_SUCCESS) return 0;
    MMCPU *result = calloc(cores, sizeof(MMCPU));
    if (result) for (natural_t i = 0; i < cores; i++) {
        result[i].user = info[i * CPU_STATE_MAX + CPU_STATE_USER];
        result[i].system = info[i * CPU_STATE_MAX + CPU_STATE_SYSTEM];
        result[i].idle = info[i * CPU_STATE_MAX + CPU_STATE_IDLE];
        result[i].nice = info[i * CPU_STATE_MAX + CPU_STATE_NICE];
    }
    vm_deallocate(mach_task_self(), (vm_address_t)info, count * sizeof(integer_t));
    *out = result; return result ? cores : 0;
}
int mm_memory(MMMemory *out) {
    vm_statistics64_data_t info; mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&info, &count) != KERN_SUCCESS) return 0;
    uint64_t total = 0; size_t len = sizeof(total); sysctlbyname("hw.memsize", &total, &len, NULL, 0);
    vm_size_t page; host_page_size(mach_host_self(), &page);
    out->total = total; out->free = (uint64_t)info.free_count * page;
    out->active = (uint64_t)info.active_count * page; out->inactive = (uint64_t)info.inactive_count * page;
    out->wired = (uint64_t)info.wire_count * page; out->compressed = (uint64_t)info.compressor_page_count * page;
    struct xsw_usage swap; len = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &len, NULL, 0) == 0) { out->swap_total = swap.xsu_total; out->swap_used = swap.xsu_used; }
    return 1;
}
int mm_network(MMNetwork *out) {
    struct ifaddrs *list; if (getifaddrs(&list) != 0) return 0;
    out->received = out->sent = 0;
    for (struct ifaddrs *it = list; it; it = it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family != AF_LINK || !it->ifa_data || !(it->ifa_flags & IFF_UP) || (it->ifa_flags & IFF_LOOPBACK)) continue;
        struct if_data *data = (struct if_data *)it->ifa_data;
        out->received += data->ifi_ibytes; out->sent += data->ifi_obytes;
    }
    freeifaddrs(list); return 1;
}

static int mm_registry_number(io_registry_entry_t entry, CFStringRef key, int64_t *value) {
    CFTypeRef property = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
    int ok = property && CFGetTypeID(property) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)property, kCFNumberSInt64Type, value);
    if (property) CFRelease(property);
    return ok;
}
void mm_hardware(MMHardware *out) {
    memset(out, 0, sizeof(*out));
    io_iterator_t iterator = IO_OBJECT_NULL;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS) {
        io_registry_entry_t gpu;
        while ((gpu = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
            CFTypeRef stats = IORegistryEntryCreateCFProperty(gpu, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
            if (stats && CFGetTypeID(stats) == CFDictionaryGetTypeID()) {
                CFTypeRef value = CFDictionaryGetValue((CFDictionaryRef)stats, CFSTR("Device Utilization %"));
                int percent = 0;
                if (value && CFGetTypeID(value) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &percent) && percent >= 0 && percent <= 100) { out->gpu_available = 1; out->gpu_percent = percent; }
            }
            if (stats) CFRelease(stats);
            IOObjectRelease(gpu);
            if (out->gpu_available) break;
        }
        IOObjectRelease(iterator);
    }
    io_service_t battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"));
    if (battery) {
        int64_t cycles = 0, design = 0, maximum = 0;
        if (mm_registry_number(battery, CFSTR("CycleCount"), &cycles) && mm_registry_number(battery, CFSTR("DesignCapacity"), &design) && mm_registry_number(battery, CFSTR("AppleRawMaxCapacity"), &maximum) && cycles >= 0 && design > 0 && maximum > 0) {
            out->battery_available = 1; out->cycle_count = (int)cycles; out->design_capacity = design; out->max_capacity = maximum;
        }
        IOObjectRelease(battery);
    }
}

void mm_disk_io(MMDiskIO *out) {
    memset(out, 0, sizeof(*out));
    io_iterator_t iterator = IO_OBJECT_NULL;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) != KERN_SUCCESS) return;
    io_registry_entry_t disk;
    while ((disk = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        CFTypeRef stats = IORegistryEntryCreateCFProperty(disk, CFSTR("Statistics"), kCFAllocatorDefault, 0);
        if (stats && CFGetTypeID(stats) == CFDictionaryGetTypeID()) {
            CFTypeRef readValue = CFDictionaryGetValue((CFDictionaryRef)stats, CFSTR("Bytes (Read)"));
            CFTypeRef writeValue = CFDictionaryGetValue((CFDictionaryRef)stats, CFSTR("Bytes (Write)"));
            int64_t read = 0, write = 0;
            if (readValue && writeValue && CFGetTypeID(readValue) == CFNumberGetTypeID() && CFGetTypeID(writeValue) == CFNumberGetTypeID() && CFNumberGetValue((CFNumberRef)readValue, kCFNumberSInt64Type, &read) && CFNumberGetValue((CFNumberRef)writeValue, kCFNumberSInt64Type, &write) && read >= 0 && write >= 0) {
                out->read_bytes += (uint64_t)read; out->write_bytes += (uint64_t)write; out->available = 1;
            }
        }
        if (stats) CFRelease(stats);
        IOObjectRelease(disk);
    }
    IOObjectRelease(iterator);
}
