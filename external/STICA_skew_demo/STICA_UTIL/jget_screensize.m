function [a, b]=jget_screensize;% s=jget_screensize;figure(1);a=get(gcf,'Parent');s=get(a,'ScreenSize');a=s(3);b=s(4);