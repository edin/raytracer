## Ada implementation

This requires some Ada 202x features.

Rather than pack everything into one file, I organized this implementation into packages, each of which has a specification and an implementation. This helps a bit with readability, but also with debugging and optimization. On the other hand, it has the side effect of making it seem longer,since every package has a specification and body. According to GNAT Studio, the version at the time of this writing has 601 lines of code.

I implemented this four different ways, all of them appearing in some version of `objects.ad?_*`. The difference lies in how each implements `Thing_Type`.

* `fptr` uses function pointers, much the same way some other languages implement object-oriented programming (C, Oberon).
* `nondiscriminated` uses a kludge to implement the same thing without variant.
* `tagged` uses "tagged records", Ada's mechanism for object-oriented programming.
* `variant` uses "variant records", akin to what other languages call "union" types. These are also known as "discriminated" records on account of the discriminant used to define `Thing_Type`.

The natural way to implement this in Ada is with the variant type, and that is how I have left it. To try a different version, just copy the corresponding files over `objects.ads` and `objects.adb`.
