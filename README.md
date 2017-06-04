# mysql_base

Base Minetest mod to connect to a MySQL database. Used by other mods to read/write data.

# Installing

Get this repository's contents using `git`, and make sure to fetch submodules
(`git submodule update --init`).

# Configuration

First, if mod security is enabled (`secure.enable_security = true`), this mod must be added as
a trusted mod (in the `secure.trusted_mods` config entry). There is **no** other solution to
make it work under mod security.

By default `mysql_base` doesn't run in singleplayer. This can be overriden by setting
`mysql_base.enable_singleplayer` to `true`.

Configuration may be done as regular Minetest settings entries, or using a config file, allowing
for more configuration options; to do so specify the path as `mysql_base.cfgfile`. This config
must contain a Lua table that can be read by `minetest.deserialize`, i.e. a regular table
definition follwing a `return` statement (see the example below).

When using flat Minetest configuation entries, all the following option names must be prefixed
with `mysql_base.`. When using a config file, entries are to be hierarchised as per the dot
separator.

Values written next to option names are default values.

## Database connection

### Minetest flat config file

Values after the  "`=`" are the default values used if unspecified.
```
mysql_base.db.host = 'localhost'
mysql_base.db.user = nil -- MySQL connector defaults to current username
mysql_base.db.pass = nil -- Using password: NO
mysql_base.db.port = nil -- MySQL connector defaults to either 3306, or no port if using localhost/unix socket
mysql_base.db.db = nil -- <== Setting this is required
```

### Lua table config file

Connection options are passed as a table through the `db.connopts` entry.
Its format must be the same as [LuaPower's MySQL module `mysql.connect(options_t)` function][mycn],
that is (all members are optional);

```lua
return {
  db = {
    connopts = {
      host = ...,
      user = ...,
      pass = ...,
      db = ...,
      port = ...,
      unix_socket = ...,
      flags = { ... },
      options = { ... },
      attrs = { ... },
      -- Also key, cert, ca, cpath, cipher
    }
  }
}
```

## Examples

### Example 1

#### Using a Lua config file

`minetest.conf`:
```
mysql_auth.cfgfile = /srv/minetest/skyblock/mysql_auth_config
```

`/srv/minetest/skyblock/mysql_auth_config`:
```lua
return {
  db = {
    connopts = {
      user = 'minetest',
      pass = 'BQy77wK$Um6es3Bi($iZ*w3N',
      db = 'minetest'
    },
  }
}
```

#### Using only Minetest config entries

`minetest.conf`:
```
mysql_auth.db.user = minetest
mysql_auth.db.pass = BQy77wK$Um6es3Bi($iZ*w3N
mysql_auth.db.db = minetest
```

# License

`mysql_base` is licensed under [LGPLv3](https://www.gnu.org/licenses/lgpl.html).

Using the Public Domain-licensed LuaPower `mysql` module.


[mycn]: https://luapower.com/mysql#mysql.connectoptions_t---conn
