package MT::Plugin::YearEntry;

use strict;

use base qw{ MT::Plugin };
use MT::Util qw/ start_end_month /;
require MT::Entry;



my $plugin = MT::Plugin::YearEntry->new({
    id => 'yearentry',
    key => __PACKAGE__,
    name => 'YearEntry',
    version     => '0.3',
    description => 'Picup Entries by Year.',
    author_name => 'felyce(Dai Takahashi)',
    author_link => 'http://felyce.info/',
    doc_link    => 'http://felyce.info/',

    registry => {
        tags => {
            function => {
                'EntryYear' => \&hdler_EntryYear,
                'YearEntriesCount' => \&hdler_YearEntriesCount,
                'YearMonthEntriesCount' => \&hdler_YearMonthEntriesCount,
            },
            block => {
                'YearEntries' => \&hdler_YearEntries,
                'YearMonthEntries' => \&hdler_YearMonthEntries,
            },
        },
    }
                                        });
MT->add_plugin( $plugin );

sub doLog{
    use MT::Log;
    use Data::Dumper;

    my ($msg) = @_;
    my $log = MT::Log->new;

    if(defined($msg)){
        $log->message(Dumper($msg));
    }
    else {
        $log->message('val:undef');
    }

    $log->save or die $log->errstr;
}

sub _getEntryYear {
    my ($entry, $offset_year) = @_;

    my $current_authored_on = $entry->column_values->{'authored_on'};
    
    $current_authored_on =~ s/^(\d\d\d\d)\d{10}/$1/;
    my $year = $current_authored_on - abs($offset_year);

    return $year;
}

sub hdler_EntryYear {
    my ($ctx, $args) = @_;
    my $tag = 'MTEntryYear';
    (my $entry = $ctx->stash('entry')) || return _no_entry_error($tag);

    # デフォルトで前年のエントリにする
    my $picup_year = $args->{year} || 1;

    return _getEntryYear($entry, $picup_year);
}

sub hdler_YearEntriesCount {
    my ($ctx, $args) = @_;
    my $tag = 'MTYearEntriesCountCount';
    (my $entry = $ctx->stash('entry')) || return _no_entry_error($tag);

    my $blog_id = $ctx->stash('blog_id');
    my $picup_year = $args->{year} || 1;

    my $year = _getEntryYear($entry, $picup_year);

    my $term = {
        blog_id       => $blog_id,
        authored_on   => [ $year.'0101000000', $year.'1231235959' ],
    };

    my $arg = { range_incl => { authored_on => 1 } };

    my @entries = MT::Entry->load($term, $arg);

    return @entries;

}

sub hdler_YearMonthEntriesCount {

    my ($ctx, $args) = @_;
    my $tag = 'MTYearEntriesCount';
    (my $entry = $ctx->stash('entry')) || return _no_entry_error($tag);

    my $blog_id = $ctx->stash('blog_id');
    my $picup_year = $args->{year} || 1;

    # authored_on から $picup_year年を引く。
    # $picup_year * 10000000000 で年から$picup_year年を引く計算となる。
    my $current_authored_on =
        $entry->column_values->{'authored_on'} - ($picup_year*10000000000);
    my ($start_month, $end_month) = start_end_month($current_authored_on);

    my $term = {
        blog_id       => $blog_id,
        authored_on   => [ $start_month, $end_month ],
    };

    my $arg = {
        range_incl => { authored_on => 1 }
    };

    my @entries = MT::Entry->load($term, $arg);

#    doLog("start_month:".$start_month);
#    doLog("end_month:".$end_month);

    return @entries;
}

sub hdler_YearMonthEntries {
    my ($ctx, $args, $cond) = @_;
    my $tag = 'MTYearMonthEntries';
    
    (my $current_entry = $ctx->stash('entry')) || return _no_entry_error($tag);

    my $blog_id = $ctx->stash('blog_id');
    my $picup_year = $args->{year} || 1;
#    my $picup_month = $args->{month} || 0;

    my $current_authored_on = $current_entry->column_values->{'authored_on'};
    #   $current_authored_on =~ /^(\d\d\d\d)(\d\d)(\d{8})/;
    $current_authored_on =~ /^(\d\d\d\d)(\d{10})/;
    my $current_year  = $1;
    my $current_other = $2;

    # my $current_month = $2;
    # my $current_other = $3;

    my $target_year = $current_year - abs($picup_year);
#    my $target_month = $current_month - abs($picup_month);

    # if( $target_month < 0 ){
    #     # 複数年前の場合(-33ヶ月とか)の対処
    #     my $before_year  += $target_month / 12;
    #     my $before_month  = $target_month % 12;

    #     $target_year  = $current_year - $before_year;
    #     $target_month = $current_month - $before_month;
    # }

    my ($start_month, $end_month) = start_end_month($target_year.$current_other);

    # doLog('picup:'.$target_year.$target_month.$current_other);
    # doLog('start:'.$start_month);
    # doLog('end:'.$end_month);

    _publish($ctx, $args, $cond, $blog_id, $start_month, $end_month);
}

sub hdler_YearEntries {
    my( $ctx, $args, $cond ) = @_;
    my $tag = 'MTYearEntries';

    (my $current_entry = $ctx->stash('entry')) || return _no_entry_error($tag);

    my $blog_id = $ctx->stash('blog_id');
    my $picup_year = $args->{year};

    $picup_year = _getEntryYear($current_entry, $picup_year);

    # range
    my $picup_start = $picup_year . '0101000000';
    my $picup_end   = $picup_year . '1231235959';

	_publish($ctx, $args, $cond, $blog_id, $picup_start, $picup_end);

}

sub _publish {

	my ($ctx, $args, $cond, $blog_id, $start_time, $end_time) = @_;
    
    my $lastn = $args->{lastn} || 10;

    my $term = {
        blog_id       => $blog_id,
        authored_on   => [ $start_time, $end_time ],
    };

    my $arg = {
        sort        => 'authored_on',
        direction   => 'descend',
        limit       => $lastn,
        range_incl  => { authored_on => 1 },
    };
    
    my $iter = MT::Entry->load_iter($term, $arg) or return '';


    my $out;
    while( my $entry = $iter->()) {

        local $ctx->{__stash}{entry} = $entry;
        local $ctx->{current_timestamp} = $entry->authored_on;
        local $ctx->{modification_timestamp} = $entry->modified_on;
        
        my $tokens = $ctx->stash('tokens');
        my $builder = $ctx->stash('builder');
        $out .= $builder->build($ctx, $tokens) or return $ctx->error($builder->errstr);
    }

    $out;
}

1;

