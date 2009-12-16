
#==================================================================== -*-perl-*-
#
# DateTime::Event::Predict::Profile
#
# DESCRIPTION
#   Provides default profiles 
#
# AUTHORS
#   Brian Hann
#
#===============================================================================

package DateTime::Event::Predict::Profile;

our %PROFILES = ();

$PROFILES{'default'} = {
	buckets => {
		'day_of_week'  => 1,
		'day_of_month' => 1,
		'day_of_year'  => 1,
	},
};

$PROFILES{'holiday'} = {
	buckets => {
		'day_of_year' => 1,
	},
};

1;

__END__

=pod

=head1 NAME

DateTime::Event::Predict::Profile - Provides default profiles for use with DateTime::Event::Predict

=head1 SYNOPSIS

Given a set of dates this module will predict the next date or dates to follow.

Perhaps a little code snippet.

    use DateTime::Event::Predict;

    my $dtp = DateTime::Event::Predict->new();
    
    my $date = new DateTime->today();
    
    $dtp->add_date($date);
    
    $dtp->predict;

=head1 PROFILES

=head1 TODO

* Make this object oriented?

=head1 AUTHOR

Brian Hann, C<< <brian.hann+dtp at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-datetime-event-predict at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DateTime-Event-Predict>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DateTime::Event::Predict


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DateTime-Event-Predict>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DateTime-Event-Predict>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DateTime-Event-Predict>

=item * Search CPAN

L<http://search.cpan.org/dist/DateTime-Event-Predict/>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2009 Brian Hann, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
