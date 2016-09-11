if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-12";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);
import unicode;

size(200, 200, IgnoreAspect);

import graph;

real f1(real x)
{
    return 6.17*x+80.19;
}

dot(( 2,  89.2));
dot(( 3,  98.3));
dot(( 4, 104.9));
dot(( 5, 112.0));
dot(( 6, 118.1));
dot(( 7, 123.4));
dot(( 8, 131.3));
dot(( 9, 136.4));
dot((10, 142.5));
dot((11, 151.1));
dot((12, 155.4));
dot((13, 159.8));
dot((14, 161.5));

draw(graph(f1, 1, 14.5));

xaxis("år", YEquals(80), arrow=Arrow, RightTicks(new real[]{2,4,6,8,10,12,14}, new real[]{1,3,5,7,9,11,13}));
yaxis("cm", arrow=Arrow, LeftTicks(new real[]{90, 100, 110, 120, 130, 140, 150, 160}));

