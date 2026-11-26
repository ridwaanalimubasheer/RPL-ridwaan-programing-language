# RPL — Ridwaan Programming Language

RPL is a programming language project I'm building from scratch. The idea is to make programming easier to read by using simple English commands.

The project is currently in development. I'm starting with a compiler, a custom binary format and a virtual machine.

## What is RPL?

RPL stands for Ridwaan Programming Language.

I want it to be a language where writing code feels simple and understandable, without losing the ability to build more advanced programs.

## Example

```rpl
say "Hello World"

make score equal 100

add 25 to score

say score

repeat 3 times
    say "RPL is running!"
end
```

## Main goals

- Simple English commands
- Own compiler
- Custom binary bytecode format
- RPL virtual machine
- Variables and calculations
- Conditions and loops
- Functions
- File handling
- Future support for game development

## How it works

RPL is planned to work in three main stages:

1. The compiler reads the `.rpl` source code.
2. It converts the instructions into RPL binary bytecode.
3. The RPL virtual machine reads and executes that bytecode.

Compiled RPL programs will use the `.rbc` extension.

## Development

RPL is still experimental. Features are being added and tested one at a time.

Current development priorities:

- Build the compiler.
- Design the binary instruction format.
- Develop the virtual machine.
- Add more language commands.
- Write documentation and examples.

## Future plans

I want to develop RPL into a useful general-purpose programming language. Game development is one of the long-term goals, but the language itself comes first.

## Contributing

Suggestions, bug reports and improvements are welcome. Please open an issue before making major changes.

## License

The project licence will be specified in the `LICENSE` file.

---

**RPL — Ridwaan Programming Language**

*Still building. More to come.*
