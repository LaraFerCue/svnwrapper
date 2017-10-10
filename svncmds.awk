BEGIN {
	filter = 1;
}
/^Available subcommands:$/ {
	filter = 0;
	next;
}
{
	if (filter == 1)
		next;
	else if ($0 ~ /^[[:space:]]/ )
		print $1;
}
