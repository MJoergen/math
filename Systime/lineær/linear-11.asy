if(!settings.multipleView) settings.batchView=false;
settings.tex="pdflatex";
defaultfilename="linear-11";
if(settings.render < 0) settings.render=4;
settings.outformat="";
settings.inlineimage=true;
settings.embed=true;
settings.toolbar=false;
viewportmargin=(2,2);

size(0,200);

import graph;

real f1(real x)
{
    return 0.6*x+1;
}

pair F1(real x)
{
    return (x, f1(x));
}

pair p1 = F1(1) + (0, 0.5);
pair p2 = F1(3) - (0, 0.5);
pair p3 = F1(4) + (0, 0.7);
pair p4 = F1(6) - (0, 1.0);

dot(p1);
dot(p2);
dot(p3);
dot(p4);

draw(graph(f1, -0.5, 7));
draw(F1(1)..p1);
draw(F1(3)..p2);
draw(F1(4)..p3);
draw(F1(6)..p4);
label("$d_1$", (F1(1)+p1)/2, W);
label("$d_2$", (F1(3)+p2)/2, E);
label("$d_3$", (F1(4)+p3)/2, W);
label("$d_4$", (F1(6)+p4)/2, E);

label("m", F1(7), S*2);

xaxis(arrow=Arrow);
yaxis(arrow=Arrow);

//fixedscaling((-0.5, -6), (4, 6));
