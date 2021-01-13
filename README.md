## docker-apk-packager
- Write something here when I can be bothered

## Usage
```
docker run -d --rm \
  -v <path to key.rsa>:/config/<keyname.rsa> \
  -v <path to APKBUILD folder>:/config/<folder name> \
  -v <path to output>:/out \
vcxpz/apk-packager
```

- Add more information when I can  be bothered
