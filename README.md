# dotenvx-flake
A nix flake to build a [dotenvx](https://github.com/dotenvx/dotenvx) binary.
## Usage
```bash
$ touch .env
$ nix run github:noblepayne/dotenvx-flake -- set ENV DEV            
✔ set ENV with encryption (.env)
✔ key added to .env.keys (DOTENV_PRIVATE_KEY)
$ nix run github:noblepayne/dotenvx-flake -- run -- bash -c 'env | grep ^ENV'
[dotenvx@1.5.0] injecting env (2) from .env
ENV=DEV
```
