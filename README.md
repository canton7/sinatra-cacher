Sinatra-cacher
==============

What is it?
-----------

Sinatra-cacher is a lightweight Sinatra extension which allows for easy page and fragment caching.
Perhaps its most important feature is that it caches at the route level -- so your route will never be called unless it needs to be.
It also handles ETag generation, flexible tags, and some other very cool stuff.
Read on to know more!

How to I start using it?
------------------------

Firstly, install the gem with

    gem install sinatra-cacher

or add it to your `Gemfile` with

    gem 'sinatra-cacher'

Next, with modular applications, you'll want to do this:

```ruby
require 'sinatra/base'
require 'sinatra/cacher'

class Application < Sinatra::Base
  register Sinatra::Cacher

  ...
end
```

or, if you're into classic applications, try this:

```ruby
require 'sinatra'
require 'sinatra/cacher'

# Carry on as usual
```

By default, Sinatra-cacher enables itself in the production environment.
See below if you want to change this.

Configuration Options
---------------------

Sinatra-cacher uses a sensible set of defaults, but the option's there if you want to tweak them.

#### `:cache_enabled`

Whether or not the cache is enabled. `true` => enabled, always. `false` => disabled, always.
There's also a special value, `:environment`, which means that the value of `:cache_enabled_in` is used to determine whether the cache is enabled, see below.  
Default: `:environment`

#### `:cache_enabled_in`

If `:cache_enabled = :environment`, then this option specifies which environment(s) to enable the cache in.
Can be a single value (e.g. `set :cache_enabled_in, :production`) or an array of values (e.g. `set :cache_enabled_in, [:development, :production]`).  
Default: `:production`

#### `:cache_generate_etags`

By default, Sinatra-cacher will generate ETags, which mean that only the headers will be sent to the browser if the browser already has the latest copy of the page.
Can be `true` or `false`.  
Default: `true`

#### `:cache_path`

Where the cache files will be stored, relative to `:root`.  
Default: `tmp/cache`

Tags
----

Unforunately we need to cover a little bit of groundwork before we move onto the fun stuff.

The cache is basically just a bit key-value store, which is global to your entire application.
The keys are called "tags", and the values are the bits of data which are cached.
When you app caches something, it assignes it a tag (although the tag can be auto-generated).
This tag is then used to retrieve the cached data later.

Route Caching
-------------

### Basic version

Here lies the real power of Sinatra-cacher.
Just take a look at this:

```ruby
get_cache '/', :tag => 'index' do 
  "My page, which took a long time to generate"
end
```

That's it! Well, at least the basics of it.
So what's going on here?

`get_cache` (aliased to `cache_get`) is the first bit of magic.
This method, defined by Sinatra-cacher, is required if you want to do route caching.
It will ensure that your block isn't called unless it needs to be, as well as some other cool stuff.

The `:tag => 'index'` bit assignes the tag 'index' to this route (obvious huh?).
This means that the value returned by the route will be stored under the tag 'index'.
If you give two routes the same tag, then they same cached value will be returned for each.

You can also assign the value `:auto` to `:tag` (or the value `true`), and Sinatra-cacher will auto-generate your tag based on the current URL (based on `request.path_info`).
To be honest, you'll probably end up doing this most of the time, but the power to manually specify your tags is there if you want it.

### Delayed version

"But what if I don't know my tag when I define the route?" I hear you cry.
This can often happen when you've got one route which serves multiple pages, or you need to do some logiking before you'll know whether you want to return the cached version of the page or not.

Look at this.

```ruby
get_cache '/'
  puts "This will always be printed"
  cache_tag 'index'
  puts "This will only be printed once"
  erb :some_page
end
```

Did you see that?
In case you missed it, the magic is `cache_tag`.

This allows you to specify the tag for the route at some point inside the route (not that you don't want to specify `:tag => 'whatever' as an argument to `get_cache` if you do this).
Everything above the call to `cache_tag` will be executed on every request.
The tag will then be used to retrieve cached content, and if it exists, the rest of the route won't be executed.

### Cache Overwriting

If you want to nuke the cache and re-write it, without having to call `cache_clear` on it (see below), you can use `cache_overwrite`.
If this method is called **before** `cache_tag` (this doesn't work with the `:tag => 'tag'` syntax), then the cache wil be overwritten and not used.

You can also pass `:overwrite => true` as an argument to `cache_tag`, e.g.  
```ruby
cache_tag 'tag', :overwrite => true
```

Block Caching
-------------

Block caching is useful when you want to cache the result of an expensive operation, but you don't want to cache an entire route.
You use it like this:

```ruby
get '/' do 
  @var = cache_block('the_tag'){ some_expensive_operation }
  erb :file
end
```

As you've probably guessed, the result of `some_expensive_operation` is cached under the tag 'the_tag'.
If a cached result is found, `some_expensive_operation` won't be called, and the block will just return the cached value.

If the object returned from the block is non-string, it wil be serialized using `Marshal.dump` in order to be stored, so there are obvious limitations here.

As with `cache_tag`, if you want to force the cache to be overwritten, you can pass `:overwrite => true`, e.g.

```ruby
@var = cache_block('the_tag', :overwrite => true){ some_expensive_operation }
```

Fragment Caching
----------------

Block caching doesn't, however, allow you to cache HTML, e.g. from inside a view.
For this, you need fragment caching.

Note that for fragment caching to work, you'll need to install and require the sinatra-outputbuffer module (Sinatra-cacher doesn't include this by default to keep resource usage low).

For example:

```ruby
require 'sinatra/base'
require 'sinatra/cached'
require 'sinatra/outputbuffer'

class Application < Sinatra::Base
  register Sinatra::Cacher
  register Sinatra::OutputBuffer

  get '/' do 
    erb :index
  end
end

__END__

@@ index
<% cache_fragment('the_tag') do %>
  <%= some_expensive_operation %>
<% end %>
```

As with block caching, `some_expensive_operation` will only be called if the value returned by the block has not yet been cached.

As with `cache_tag`, if you want to force the cache to be overwritten, you can pass `:overwrite => true`, e.g.

```ruby
<% cache_fragment('the_tag', :overwrite => true) do %>
```

A Note On File Paths
--------------------

In order to understand clearing caches (the next bit), you first need to know how Sinatra-cacher stores its data.

The tag directly determines the path under which the data is stored.
If the tag contains slashes ('/'), these are interpreted as directory separators.
If the tag contains no file extension, '.html' is added.
The tag should not end in a trailing slash.

Auto-generated tags follow an additional rule: if `request.path_info` ends in a trailing slash, 'index.html' is appended.
This means that the pages 'domain.tld/page' and 'domain.tld/page/' will have different cache files.

**NOTE**: Since fragment, block, and route caches aren't really compatibe, page caches are prepended with 'pages/, block caches with 'blocks/', and fragment caches with 'fragments/'.

Some examples:

Tag                 | Cache File
--------------------|-----------------
'index'             | '/index.html'
'foo/bar'           | '/foo/bar.html'
'css/file.css'      | '/css/file.css'

`request.path_info` | Cache File
--------------------|-------------------
'path'              | '/path.html'
'path/'             | '/path/index.html'

Clearing Caches
---------------

Now that you understand how tags translate to file paths, you're ready for how to clear caches.

Use `cache_clear 'tag_name'`.

`tag_name` can either be the name of a tag, or a glob.
If a glob is given, all cache files which match this glob on the filesystem are destroyed.
If `tag_name` ends in a trailing slash, an asterisk is automatically appended, so 'tag_name/' becomes 'tag_name/*'.
If no tag name is given, '*' is used (i.e. delete everything).

Examples:

`cache_clear` or `cache_clear '/'`:  
Deletes everything.

`cache_clear 'pages/'`:  
Delete all page caches.

`cache_clear 'fragments/'`:  
Delete all fragment caches.

`cache_clear 'pages/index'`:
Deletes the page cache with tag 'index'.

Note that individual caches can be overwritten (without being deleted first) using the `:overwrite` argument.
See the earlier sections on route, block, and fragment caching.

ETag Generation
---------------

Proper use of Etags means that, if the browser already has an up-to-date version of the page, we don't need to send them data.
When we provide a page to the browser, we also provide a unique identifier for that page, called the ETag.
When the browser next requests that page, it send back the ETag.
If the ETag for that page hasn't changed, we just send them a header saying "You've already got this page", and save on some bandwidth.

Sinatra-cacher takes care of managing your ETags for you (disable this by setting `:cache_generate_etags` to `false`).
When it caches a page, it stores the timestamp at which it did so.
This timestamp is then presented as the ETag.
Whenever the cache changes, so does the ETag, and everything Just Works (tm).
