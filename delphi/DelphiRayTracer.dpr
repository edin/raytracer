program DelphiRayTracer;

{$APPTYPE CONSOLE}

uses
  Graphics, Windows,
  SysUtils, Diagnostics,
  RayTracer in 'RayTracer.pas';

var
  sc  : Scene;
  rt  : RayTracerEngine;
  s   : String;
  bmp : Graphics.TBitmap;
  //t1,t2:Cardinal;
  sw  : TStopwatch;
begin

  try
    bmp := Graphics.TBitmap.Create;
    bmp.PixelFormat := pf32bit;
    bmp.Width := 500;
    bmp.Height := 500;
    
    sw := TStopWatch.Create;
    
    sw.Start;
    sc := Scene.Create();
    rt := RayTracerEngine.Create();
    rt.render(sc, bmp);
    sw.Stop;

    bmp.SaveToFile('delphi-ray-tracer.bmp');

    sc.Free;
    rt.Free;
    bmp.Free;

    Writeln('Completed in: ' + IntToStr(sw.ElapsedMilliseconds) + ' ms' );

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.