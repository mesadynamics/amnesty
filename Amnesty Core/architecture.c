/*
 File: check_executable_architecture.c
 
 Abstract: command-line tool demonstrating checking executables to see 
 whether they match the current processor architecture, or a given 
 processor architecture.

 Compile: 

 cc -o check_executable_architecture -framework CoreFoundation check_executable_architecture.c

 Use:

 check_executable_architecture <file|bundle> ...
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Computer, Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Computer,
 Inc. may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright © 2005-2006 Apple Computer, Inc., All Rights Reserved
 */ 

#include <CoreFoundation/CoreFoundation.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <mach-o/fat.h>
#include <mach-o/arch.h>
#include <mach-o/loader.h>

#define BYTES_TO_READ   512

Boolean g_arch_PowerPC = false;
Boolean g_arch_Intel = false;

/*  Byte-swaps an executable's header (which consists entirely of four-byte quantities on four-byte boundaries).
*/
static void swap_header(uint8_t *bytes, ssize_t length) {
    ssize_t i;
    for (i = 0; i < length; i += 4) *(uint32_t *)(bytes + i) = OSSwapInt32(*(uint32_t *)(bytes + i));
}

/*  Determines whether an executable's header matches the current architecture, ppc, and/or i386. 
*   Returns true if the header corresponds to a Mach-O, 64-bit Mach-O, or universal binary executable, false otherwise.
*   Returns by reference the result of matching against a given architecture (matches_current, matches_ppc, matches_i386).
*   Checks for a given architecture only if the corresponding return-by-reference argument is non-NULL. 
*/
static Boolean examine_header(uint8_t *bytes, ssize_t length, Boolean *matches_current, Boolean *matches_ppc, Boolean *matches_i386) {
    Boolean retval = false;
    uint32_t magic = 0, num_fat = 0, max_fat = 0;
    struct fat_arch one_fat = {0}, *fat = NULL;
    const NXArchInfo *current_arch, *ppc_arch, *i386_arch;
    
    // Look for any of the six magic numbers relevant to Mach-O executables, and swap the header if necessary.
    if (length >= sizeof(struct mach_header_64)) {
        magic = *((uint32_t *)bytes);
        max_fat = (length - sizeof(struct fat_header)) / sizeof(struct fat_arch);
        if (MH_MAGIC == magic || MH_CIGAM == magic) {
            struct mach_header *mh = (struct mach_header *)bytes;
            if (MH_CIGAM == magic) swap_header(bytes, length);
            one_fat.cputype = mh->cputype;
            one_fat.cpusubtype = mh->cpusubtype;
            fat = &one_fat;
            num_fat = 1;
        } else if (MH_MAGIC_64 == magic || MH_CIGAM_64 == magic) {
            struct mach_header_64 *mh = (struct mach_header_64 *)bytes;
            if (MH_CIGAM_64 == magic) swap_header(bytes, length);
            one_fat.cputype = mh->cputype;
            one_fat.cpusubtype = mh->cpusubtype;
            fat = &one_fat;
            num_fat = 1;
        } else if (FAT_MAGIC == magic || FAT_CIGAM == magic) {
            fat = (struct fat_arch *)(bytes + sizeof(struct fat_header));
            if (FAT_CIGAM == magic) swap_header(bytes, length);
            num_fat = ((struct fat_header *)bytes)->nfat_arch;
            if (num_fat > max_fat) num_fat = max_fat;
        }
    }
    
    // Set the return value depending on whether the header appears valid.
    retval = ((fat && num_fat > 0) ? true : false);
    
    // Check for a match against the current architecture specification, if requested.
    if (matches_current) {
        current_arch = NXGetLocalArchInfo();
        *matches_current = ((retval && current_arch && NXFindBestFatArch(current_arch->cputype, current_arch->cpusubtype, fat, num_fat)) ? true : false);
    }
    // Check for a match against the ppc architecture specification, if requested.
    if (matches_ppc) {
        ppc_arch = NXGetArchInfoFromName("ppc");
        *matches_ppc = ((retval && ppc_arch && NXFindBestFatArch(ppc_arch->cputype, ppc_arch->cpusubtype, fat, num_fat)) ? true : false);
    }
    // Check for a match against the i386 architecture specification, if requested.
    if (matches_i386) {
        i386_arch = NXGetArchInfoFromName("i386");
        *matches_i386 = ((retval && i386_arch && NXFindBestFatArch(i386_arch->cputype, i386_arch->cpusubtype, fat, num_fat)) ? true : false);
    }
    return retval;
}

/*  Examines a regular file, determine whether it is an executable and if so which architectures it matches.
*   Prints out the results.  Caller must have checked to make sure that this is a regular file.
*/
static void examine_file(const uint8_t *path) {
    int fd = open((const char *)path, O_RDONLY, 0777);
    uint8_t bytes[BYTES_TO_READ];
    ssize_t length;
    Boolean matches_current = false, matches_ppc = false, matches_i386 = false;
    if (fd >= 0) {
        // Read the executable's header.
        length = read(fd, bytes, BYTES_TO_READ);
        // Examine it to determine whether it is an executable and if so which architectures it matches.
        if (examine_header(bytes, length, &matches_current, &matches_ppc, &matches_i386)) {
            //printf("File %s is Mach-O, %s the current architecture, %s ppc, and %s i386.\n", path, (matches_current ? "matches" : "does not match"), (matches_ppc ? "matches" : "does not match"), (matches_i386 ? "matches" : "does not match"));

			if(matches_ppc)
				g_arch_PowerPC = true;

			if(matches_i386)
				g_arch_Intel = true;
        } else {
            //printf("File %s is not Mach-O.\n", path);
        }
    } else {
        //printf("Cannot read file %s.\n", path);
    }
    if (fd >= 0) close(fd);
}

/*  Examines a directory, treating it as a bundle, and determines whether it has an executable.
*   Examines the executable as a regular file to determine which architectures it matches.
*   Prints out the results.
*/
static void examine_bundle(const uint8_t *bundle_path) {
    CFURLRef bundleURL = CFURLCreateFromFileSystemRepresentation(NULL, bundle_path, strlen((const char *)bundle_path), true), executableURL = NULL;
    CFBundleRef bundle = NULL;       
    uint8_t path[PATH_MAX];
    struct stat statBuf;
    if (bundleURL && (bundle = CFBundleCreate(NULL, bundleURL))) {
        // Try to obtain a path to an executable within the bundle.
        executableURL = CFBundleCopyExecutableURL(bundle);
        if (executableURL && CFURLGetFileSystemRepresentation(executableURL, true, path, PATH_MAX) && stat((const char *)path, &statBuf) == 0) {
            // Make sure it is a regular file, and if so examine it as a regular file.
            if ((statBuf.st_mode & S_IFMT) == S_IFREG) {
                examine_file(path);
            } else {
                printf("Unsupported file type for file %s.\n", path);
            }
        } else {
            printf("No executable located for %s.\n", bundle_path);
        }
    } else {
        printf("Cannot read %s.\n", bundle_path);
    }
    if (executableURL) CFRelease(executableURL);
    if (bundle) CFRelease(bundle);
    if (bundleURL) CFRelease(bundleURL);
}

bool
BundleArchitectureIsIntel(
	CFStringRef inBundlePath)
{
	g_arch_Intel = false;

    CFURLRef bundleURL = CFURLCreateWithFileSystemPath(NULL, inBundlePath, kCFURLPOSIXPathStyle, true), executableURL = NULL;
    CFBundleRef bundle = NULL;       
    uint8_t path[PATH_MAX];
    struct stat statBuf;
    if (bundleURL && (bundle = CFBundleCreate(NULL, bundleURL))) {
        // Try to obtain a path to an executable within the bundle.
        executableURL = CFBundleCopyExecutableURL(bundle);
        if (executableURL && CFURLGetFileSystemRepresentation(executableURL, true, path, PATH_MAX) && stat((const char *)path, &statBuf) == 0) {
            // Make sure it is a regular file, and if so examine it as a regular file.
            if ((statBuf.st_mode & S_IFMT) == S_IFREG) {
                examine_file(path);
            } else {
               // printf("Unsupported file type for file %s.\n", path);
            }
        } else {
            //printf("No executable located for %s.\n", bundle_path);
        }
    } else {
        //printf("Cannot read %s.\n", bundle_path);
    }
    if (executableURL) CFRelease(executableURL);
    if (bundle) CFRelease(bundle);
    if (bundleURL) CFRelease(bundleURL);
	
	return g_arch_Intel;
}

bool
BundleArchitectureIsPowerPC(
	CFStringRef inBundlePath)
{
	g_arch_PowerPC = false;

    CFURLRef bundleURL = CFURLCreateWithFileSystemPath(NULL, inBundlePath, kCFURLPOSIXPathStyle, true), executableURL = NULL;
    CFBundleRef bundle = NULL;       
    uint8_t path[PATH_MAX];
    struct stat statBuf;
    if (bundleURL && (bundle = CFBundleCreate(NULL, bundleURL))) {
        // Try to obtain a path to an executable within the bundle.
        executableURL = CFBundleCopyExecutableURL(bundle);
        if (executableURL && CFURLGetFileSystemRepresentation(executableURL, true, path, PATH_MAX) && stat((const char *)path, &statBuf) == 0) {
            // Make sure it is a regular file, and if so examine it as a regular file.
            if ((statBuf.st_mode & S_IFMT) == S_IFREG) {
                examine_file(path);
            } else {
               // printf("Unsupported file type for file %s.\n", path);
            }
        } else {
            //printf("No executable located for %s.\n", bundle_path);
        }
    } else {
        //printf("Cannot read %s.\n", bundle_path);
    }
    if (executableURL) CFRelease(executableURL);
    if (bundle) CFRelease(bundle);
    if (bundleURL) CFRelease(bundleURL);
	
	return g_arch_PowerPC;
}

/*  Examines each argument, determining whether it represents a directory or a regular file.
*   Treats directories as bundles and regular files as standalone executables.
*   Examines bundle or standalone executables to determine which architectures they match.
*   Prints out the results.
*/
#if 0
main(int argc, char **argv) {
    int i;
    struct stat statBuf;
    for (i = 1; i < argc; i++) {
        uint8_t *path = (uint8_t *)(argv[i]);
        if (stat((const char *)path, &statBuf) == 0) {
            // Check to see whether it is a regular file or a directory.
            if ((statBuf.st_mode & S_IFMT) == S_IFREG) {
                examine_file(path);
            } else if ((statBuf.st_mode & S_IFMT) == S_IFDIR) {
                examine_bundle(path);
            } else {
                printf("Unsupported file type for file %s.\n", path);
            }
        } else {
            printf("Cannot find %s.\n", path);
        }
    }
}
#endif