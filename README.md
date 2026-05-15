# lsc

`lsc` is a small `ls`-like command written in C.

## Install

Install directly from GitHub with `curl`:

```sh
curl -fsSL https://raw.githubusercontent.com/Saku0512/lsc/main/install.sh | sh
```

This installer will build `lsc` and install it into `/usr/local/bin` when possible.
If `/usr/local/bin` is not writable, it falls back to `$HOME/.local/bin`.

For a custom prefix:

```sh
curl -fsSL https://raw.githubusercontent.com/Saku0512/lsc/main/install.sh | sh -s -- --prefix "$HOME/.local"
```

## Build from source

```sh
make
```

## Install with Makefile

```sh
make install PREFIX=/usr/local
```
