function jset_labelsize(xyz,n);if xyz=='x'	a=get(gca,'XLabel');elseif xyz=='y'	a=get(gca,'YLabel');elseif xyz=='z'	a=get(gca,'ZLabel');else	error('jset_labelsize');end;set(a,'FontSize',n);