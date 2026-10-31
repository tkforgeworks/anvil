# anvil_core

Anvil's core without Flutter: data access, project lifecycle, the formula,
validation and export engines. The desktop app in the repository root depends
on this package; this package never depends on `package:flutter`, so every part
of it runs under plain `dart test`.

Run the tests from this directory:

```bash
dart test
```
