## Canopy

Canopy is an app to browse and inspect `sysctl` entries.

The app is similar to the [`sysctl(8)`](<https://man.freebsd.org/cgi/man.cgi?sysctl(8)>) command line tool.

Originally, I developed this app to be able to browse `sysctl` entries on iOS, however the function call this repository uses to enumerate `sysctl` entries throws "Operation not permitted" on iOS. For this reason, I am not planning to continue development on this project.

### The code

Most of the code to interact with `sysctl` is in the `SystemInformation` namespace in this repo. This code provides a nice Swift wrapper for the `sysctl(3)` call, as well as wrapping the "private" API that Canopy uses to enumerate `sysctl` entries, access their descriptions, and other data.

As the code in `SystemInformation` references, most of the code is based on Apple's open source [sysctl](https://github.com/apple-oss-distributions/system_cmds/blob/e0c267e80e451b9441ec4f4bb05dd72f0b49d596/sysctl) tool.

If you're interested in `sysctl`, I suggest reading <https://freebsdfoundation.org/wp-content/uploads/2014/01/Implementing-System-Control-Nodes-sysctl.pdf> for more details.

In short, a `sysctl` entry includes:

- name - a short string
- flags - bit-mask including type information, read/write permissions, etc.
- format string - information about how to format the stored data (_not_ a `printf` format specifier)
- description - a human readable string

Entries are referenced at runtime using a numerical path (there are functions to use the string name - see the links above; I'm simplifying here for brevity). For example:

```swift
func operatingSystemType() throws -> String {
    let path: [Int32] = [ CTL_KERN, KERN_OSTYPE ] // [ 1, 1 ]
    let bytes: [UInt8] = try SystemInformation.object(for: .init(rawValue: path))
    return String(nullTerminatedUTF8: bytes) // "Darwin"
}
```

(`CTL_KERN`, `KERN_OSTYPE` are defined in `sys/sysctl.h`)

Apple provides "private" API, that their `sysctl(8)` tool uses, to access the fields described above.
They each work by appending the original path you're interested in to the following paths:

```swift
[ CTL_SYSCTL, CTL_SYSCTL_NAME ]     // [ 0, 1 ]
[ CTL_SYSCTL, CTL_SYSCTL_NEXT ]     // [ 0, 2 ]
[ CTL_SYSCTL, CTL_SYSCTL_NAME2OID ] // [ 0, 3 ]
[ CTL_SYSCTL, CTL_SYSCTL_OIDFMT ]   // [ 0, 4 ]
[ CTL_SYSCTL, CTL_SYSCTL_OIDDESCR ] // [ 0, 5 ]
```

For example, to get the name for `[ CTL_KERN, KERN_OSTYPE ]`, we can append that to `[ CTL_SYSCTL, CTL_SYSCTL_NAME ]`:

```swift
func sysctlOperatingSystemEntryName() throws -> String {
    let path: [Int32] = [ CTL_SYSCTL, CTL_SYSCTL_NAME, CTL_KERN, KERN_OSTYPE ] // [ 0, 1, 1, 1 ]
    let bytes: [UInt8] = try SystemInformation.object(for: .init(rawValue: path))
    return String(nullTerminatedUTF8: bytes) // "kern.ostype"
}
```

The usage of the rest of these should be fairly discernable by reading `SystemInformation`.

This project does not use `CTL_SYSCTL_NAME2OID` - I imagine it provides behavior similar to the public `sysctlnametomib(3)` API.
