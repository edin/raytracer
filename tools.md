# Tools

To build tools on Windows install dotnet and build project in "tools" directory:

https://dotnet.microsoft.com/download/dotnet/5.0

```cmd
    cd tools 
    dotnet build
```

## Compare image

```cmd
  ray imagediff --source "c\c-raytracer.bmp" --target "php\php-ray-tracer.bmp"
```

## Measure time 

Time command uses definitions from projects.xml file to build and run project. 

```cmd
  ray time --name php
  ray time --name c
  ray time --name c++
```

