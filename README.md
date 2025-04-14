# dotfiles
A fresh start on my dotfiles using the Zig build system.

## Design goals

Allow for building small utilities.
Build a [river](https://codeberg.org/river/river) init program using Zig.
Allow for copying over specific program configs.

And have fun doing something crazy with the Zig build system.


## Populating configs

The following will move all the config files to their respective locations.
The subfolders will be copied as is, so makes sure the `config` folder has the names correct.

```bash
zig build -Dall=true --prefix $HOME/.config

# or a specific program
zig build -Dwaybar=true --prefix $HOME/.config
```
