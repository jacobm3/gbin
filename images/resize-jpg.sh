longedge=1920
q=90
mkdir img-${longedge}-${q}
for x in *JPG; do convert $x -verbose -resize $longedge -quality $q img-${longedge}-${q}/${longedge}.q${q}.${x}; done
