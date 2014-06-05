MultiTunnels
=======

![image](http://i.imgur.com/Ej5dz.png)

MultiTunnels is a proxy to http/https from http/https.

You can run the [Pow](http://pow.cx/) over SSL!

Installation
------------

    $ gem install multitunnels

Run
---

    $ sudo multitunnels

If you are using rvm:

    $ rvmsudo multitunnels

By default, proxy to 80 port from 443 port.

specify "http" port and "https" port:

    $ sudo multitunnels 443 3000

or

    $ sudo multitunnels 127.0.0.1:443 127.0.0.1:3000
or

    $ sudo multitunnels https://127.0.0.1:443 http://127.0.0.1:3000

You can also proxy to 443 port from 80 port.

    $ sudo multitunnels http://127.0.0.1:80 https://127.0.0.1:443

If hostname is '127.0.0.1' or 'localhost', you can choose to omit them.

    $ sudo multitunnels http://:80 https://:443

You can proxy to other host, then you can `curl http://localhost:3000` to visit Google Hongkong

    $ multitunnels http://:3000 https://www.google.com.hk:443

You can proxy from Baidu to Google :) someone might be confused (do not forget to add entry `127.0.0.1 www.baidu.com` to /etc/hosts)

    $ sudo multitunnels http://www.baidu.com https://www.google.com.hk

As the name implies, you can create lots of proxies in one command (but do not forget to add entry `127.0.0.1 www.baidu.com www.samsung.com` to /etc/hosts)

    $ sudo multitunnels http://www.baidu.com https://www.google.com.hk http://www.samsung.com http://www.apple.com 443 80 8000 3000

This command creates four proxies.

Compatibility
---------
MRI Ruby >= 1.8.7

Copyright
---------

Copyright (c) 2012 jugyo, released under the MIT license.
