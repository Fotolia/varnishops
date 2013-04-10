# varnishops

varnishops is a tool for analyzing and categorizing traffic on your varnish servers in realtime.

It gathers the output of varnishncsa and create statistics such as request rate, output bandwidth or hitratio.

URLs from varnishncsa are categorized using custom regular expressions, based on your assets' paths and classification (example provided in **ext/**)

varnishops is written in Ruby (tested with MRI 1.9.3) and depends only on varnishncsa.

## Setup

 * git clone https://github.com/Fotolia/varnishops
OR
 * gem install varnishops


By default, all URLs will be categorized as "other", and statistics will be computed based on the global varnish traffic

Categories can be added by defining filters (ruby regexps). See example file in **ext/**.

## Credits

varnishops is heavily inspired by [mctop](http://github.com/etsy/mctop) from Etsy's folks.
