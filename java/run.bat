@set outputDir=bin
@if not exist %outputDir% (mkdir %outputDir%)
@javac -d bin   RayTracer.java
@java -cp .\bin RayTracer 