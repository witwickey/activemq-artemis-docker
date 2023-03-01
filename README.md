## ACTIVELY MAINTAINED BUT NOT ACTIVELY SUPPORTED FOR OTHER USERS
### (Welcome but don't expect quick answers to questions or feature requests)

Since the author of the ["vromero"](https://github.com/vromero/activemq-artemis-docker) image - well done to him - stopped maintaining it at v2.16 I forked it here and will release new Artemis versions at [Docker Hub](https://hub.docker.com/r/qoricode/activemq-artemis) as they are released on "reasonable endeavours". Note I'm not planning to maintain the Alpine ones, only the Debian ones.

Also fixed a few minor issues (from my point of view) - 
- Old 2016 version of ca-certificates was baked in - now pulls latest.
- Internet fetch operations were muted during the build - now reports e.g. certificate issues during build and pulls artemis signing keys via https.
- ENABLE_JMX and ENABLE_JMX_EXPORTER would be enabled on any value e.g. false, now will only be enabled if == true.
- ENABLE_JMX_EXPORTER would activate ENABLE_JMX when not actually needed - now independent of each other.
    - Note ENABLE_JMX actually enables remote, anonymous JMX access. (Local) JMX is enabled via broker.xml and on by default.

## License

View [license information](http://www.apache.org/licenses/LICENSE-2.0) for the software contained in this image.
