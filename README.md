# Outatime

For users of versioned AWS S3 buckets. This command-line tool will allow you to download a snapshot of the files in that bucket from a given point in time.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'outatime'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install outatime

## Usage

```
outatime -r {region} -b {bucket-name} -f {date} -p {subdirectory} --profile {aws profile name}
```

Example:
```
outatime -r us-east-1 -b my-bucket -f '21 Oct 2015' -p schematics/hoverboard --profile aws-profile
```

## Development

After checking out the repo, run `bundle` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pressednet/outatime.

## LICENSE

MIT License, see [LICENSE](LICENSE) for details.
