wget --mirror            \
     --convert-links     \
     --html-extension    \
     --wait=0.25            \
     --span-hosts \
     -o wget-mirror.log              \
     --reject zip,gz,tgz \
     $1

