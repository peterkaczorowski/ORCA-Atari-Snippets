# ORCA-Atari-Snippets

Small, self-contained Atari 8-bit programs built with the **native ORCA/M
toolchain running under SpartaDOS X** — the 65816 assembler and linker on the
Atari itself, not a cross-assembler on something else.

Each project is one concern, written out in full: the source, the recipes it
needs, the artifact it produces, and a `do.bat` that is the build exactly as it
runs on the machine.

| project | what it is | artifact |
|---|---|---|
| [`cpu_detect`](cpu_detect/) | identifies the CPU family and writes the answer into the top-left screen cell | `CPUDET.COM`, 184 bytes |
| [`cpu_detect_car`](cpu_detect_car/) | the same probe packaged as a plain 8 KB cartridge at `$A000` | `CPUDETC.CAR`, 8208 bytes |

## A note on how these are written

These snippets — the sources, the recipes and the prose around them — are
written with the help of an AI assistant, under human direction and review.

Every artifact checked in was built and run before it was committed, and the
numbers quoted in the READMEs are measured rather than asserted. Read them as
what they are all the same: small programs published so they can be checked,
not authority to be taken on trust.

