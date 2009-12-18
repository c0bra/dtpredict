#!/usr/bin/perl

	use lib qw( ../lib );

	use DateTime;
	use DateTime::Event::Predict;

	my $profile = new DateTime::Event::Predict::Profile(
		buckets => [qw/ day_of_week /],
	);

    my $dtp = DateTime::Event::Predict->new(
		profile => $profile,	
	);
    
    # Add todays date 12/17/2009
    my $date = DateTime->today();
    $dtp->add_date($date);
    
    # Add the previous 5 days
    for  (1 .. 5) {
		my $add = $_ * -1;
		#warn "ADD: $add\n";
    	my $new_date = $date->clone->add(
    		days => ($_ * -1),
    	);
		#print $new_date->mdy . "\n";
    	
    	$dtp->add_date($new_date);
    }

    #Predict the next date
    my $predicted_date = $dtp->predict;

	#use Data::Dumper;
	#warn Dumper(\@predicted_date);
   	 
	#print join("\n", map { $_->mdy('/') . ' ' . $_->hms . ' : ' . $_->{_date_deviation} } @predicted_dates) . "\n";
	print $predicted_date->ymd . "\n";
