## Development

The release requires the Ruby gem Bundler (used by the vendoring script):

```
gem install bundler
```

With bundler installed, run the vendoring script:

```
./scripts/vendor_gems
```

Then create the BOSH release:

```
bosh create release --force
```

The release is now ready for use. If everything works, commit the changes including the updated gems.

## Creating a new final release

For now this is done by hand:

1. Create `config/private.yml` with the blobstore secrets (found in `deployments-bosh` repo)
2. `bosh create release --final`
3. `git add . && git commit`

