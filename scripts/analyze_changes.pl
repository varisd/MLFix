#!/usr/bin/env perl

use strict;
use warnings;
use PerlIO::gzip;
use Lingua::Interset 2.050;
use Lingua::Interset::FeatureStructure;

# what do we report:
# 0 - changed classes
# 1 - changed classes + what changed
# 2 - all changes between old-new nodes
# 3 - changed classes - iset only
# 4 - feature clusters - feautures in cluster have equal values through the dataset
# 5 - changed agreement - iset only
# 6 - size of each feature (# values)
# 7 - changed pos
my $type = $ARGV[0];
$type = 0 if !(defined $type);

my $feat_ignore = { "new_node_form" => 1, "new_node_lemma" => 1, "new_node_tag" => 1, "new_node_afun" => 1, "new_node_edgedirection" => 1, "new_node_childno" => 1, "new_node_lchildno" => 1, "new_node_rchildno" => 1 };

#my $out_train=$ARGV[2];
#my $out_test=$ARGV[3];

my %changes = ();
my $all = 0;

my $line = <STDIN>;
chomp $line;
my @feature_names = split /\t/, $line;

if ($type == 0 || $type == 3 || $type == 5) {
    while(<STDIN>) {
        chomp;
	    $line = $_;
        my $result = "";

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;
    
        foreach my $feat_new (@feature_names) {
            next if $feat_ignore->{$feat_new};
            if( $feat_new =~ /^new_/ ) {
                my $feat_old = $feat_new;
                $feat_old =~ s/^new_/old_/;

                my $feat_root = $feat_new;
                $feat_root =~ s/^new_//;
                next if ($type == 3 && !is_iset($feat_root));
                next if ($type == 5 && !is_iset_agr($feat_root));
                $result .= "$feat_old " if ($features{$feat_old} ne $features{$feat_new});
            }
        }
        if ($result ne "") {
            $changes{$result}++;
            $all++;
        }
    }
    foreach my $key (sort { $changes{$b} <=> $changes{$a} } keys %changes) {
        my $rel = $changes{$key} / $all;
        print "$key\t" . $changes{$key} . "\t$rel\n";
    }
}
elsif ($type == 1) {
    while(<STDIN>) {
        chomp;
        $line = $_;

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;

        if ( $features{"new_node_pos"} ne $features{"old_node_pos"} ) {
            print $features{"old_node_lemma"}."(".$features{"old_node_pos"}.")". " => " .$features{"new_node_lemma"}."(".$features{"new_node_pos"}.")\n";
        }
    }
}
elsif ($type == 2) {
    while(<STDIN>) {
        chomp;
        $line = $_;

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;

        my ($form_change, $lemma_change, $tag_change, $iset_change, $parent_form_change, $parent_lemma_change, $parent_tag_change, $parent_iset_change) = (0,0,0,0,0,0,0,0);

        $form_change = 1 if ($features{"new_node_form"} ne $features{"old_node_form"});
        $lemma_change = 1 if ($features{"new_node_lemma"} ne $features{"old_node_lemma"});
        $tag_change = 1 if ($features{"new_node_tag"} ne $features{"old_node_tag"});
        $iset_change = 1 if iset_changed(\%features, "old_node", "new_node");
        $parent_form_change = 1 if ($features{"parentnew_node_form"} ne $features{"parentold_node_form"});
        $parent_lemma_change = 1 if ($features{"parentnew_node_lemma"} ne $features{"parentold_node_lemma"});
        $parent_tag_change = 1 if ($features{"parentnew_node_tag"} ne $features{"parentold_node_tag"});
        $parent_iset_change = 1 if iset_changed(\%features, "parentold_node", "parentnew_node");

        print $features{"old_node_id"} . "\t"
            . $form_change . "|" . $features{"old_node_form"} . ";" . $features{"new_node_form"} . "\t"
            . $lemma_change . "|" . $features{"old_node_lemma"} . ";" . $features{"new_node_lemma"} . "\t"
            . $tag_change . "|" . $features{"old_node_tag"} . ";" . $features{"new_node_tag"} . "\t"
            . $iset_change . "|" . get_iset(\%features, "old_node") . ";" . get_iset(\%features, "new_node") . "\t"
            . $parent_form_change . "|" . $features{"parentold_node_form"} . ";" . $features{"parentnew_node_form"} . "\t"
            . $parent_lemma_change . "|" . $features{"parentold_node_lemma"} . ";" . $features{"parentnew_node_lemma"} . "\t"
            . $parent_tag_change . "|" . $features{"parentold_node_tag"} . ";" . $features{"parentnew_node_tag"} . "\t"
            . $parent_iset_change . "|" . get_iset(\%features, "parentold_node") . ";" . get_iset(\%features, "parentnew_node") . "\n";
    }
}
elsif ($type == 4) {
    my $clusters = {};
    my $names = join ",", @feature_names;
    $clusters->{$names} = 1;
    while(<STDIN>) {
        chomp;
        $line = $_;

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;

        my $tmp_clusters = ();
        foreach my $cluster (keys %$clusters) {
            $clusters->{$cluster} = undef;
            my $new_clusters = split_cluster($cluster, \%features);
            foreach my $new_cluster (keys %$new_clusters) {
                $tmp_clusters->{$new_cluster} = 1;
            }
        }
        $clusters = $tmp_clusters;
    }
    foreach my $cluster (sort { $b cmp $a } keys %$clusters) {
#    foreach my $cluster (keys %$clusters) {
        next if $cluster eq "";
        print "$cluster\n";
    }
}
elsif ($type == 6) {
    my %feat_info = ();
    foreach my $feat (@feature_names) {
        $feat_info{$feat} = {};
    }
    while(<STDIN>) {
        chomp;
        $line = $_;
        my $result = "";

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;

        foreach my $feat (@feature_names) {
            $feat_info{$feat}->{$features{$feat}} = 1;
        }
    }
    foreach my $key (sort { scalar keys %{ $feat_info{$b} } <=> scalar keys %{ $feat_info{$a} } } keys %feat_info) {
        my $size = scalar keys %{ $feat_info{$key} };
        print "$key\t$size\n";
    }
}
elsif ($type == 7) {
    while(<STDIN>) {
        chomp;
        $line = $_;
        my $result = "";

        my %features = ();
        @features{ @feature_names } = split /\t/, $line;

        foreach my $feat_new (@feature_names) {
            next if $feat_ignore->{$feat_new};
            if( $feat_new =~ /^new_/ ) {
                my $feat_old = $feat_new;
                $feat_old =~ s/^new_/old_/;

                my $feat_root = $feat_new;
                $feat_root =~ s/^new_//;
                next if ($type == 3 && !is_iset($feat_root));
                next if ($features{$feat_old} eq $features{$feat_new});
                $changes{$features{"old_node_pos"}}++;
                $all++;
                last;
            }
        }
    }
    foreach my $key (sort { $changes{$b} <=> $changes{$a} } keys %changes) {
        my $rel = $changes{$key} / $all;
        print "$key\t" . $changes{$key} . "\t$rel\n";
    }
}

sub iset_changed {
    my ($features, $prefix1, $prefix2) = @_;
    
    my $result = 0;
    foreach my $feature (Lingua::Interset::FeatureStructure->known_features()) {
        $result = 1 if $features->{"${prefix1}_${feature}"} ne $features->{"${prefix2}_${feature}"};
    }
    return $result;
}

sub get_iset {
    my ($features, $prefix) = @_;

    my $result = "";
    foreach my $feature (Lingua::Interset::FeatureStructure->known_features()) {
        if (defined $features->{"${prefix}_${feature}"}) { $result .= $features->{"${prefix}_${feature}"} . ":"; }
        else { $result .= ":"; }
    }
    return $result;
}

sub is_iset {
    my ($feat) =  @_;
    
    foreach my $feature (Lingua::Interset::FeatureStructure->known_features()) {
        return 1 if "node_$feature" eq $feat;
    }

    return 0;
}

sub is_iset_agr {
    my ($feat) = @_;

    return 0 if $feat !~ /-agr/;

    my $feat_root = $feat;
    $feat_root =~ s/-agr//;
    return is_iset($feat_root);
}

sub split_cluster {
    my ($cluster_str, $feat_hash) = @_;
    my %processed = ();
    my @cluster = split /,/, $cluster_str;
    my $output_clusters = {};
    foreach my $feat (@cluster) {
        my @new_cluster = ();
        push @new_cluster, $feat;
        next if $processed{$feat};
        $processed{$feat} = 1;
        foreach my $other_feat (@cluster) {
            next if $feat eq $other_feat;
            next if $processed{$other_feat};
            if ($feat_hash->{$feat} eq $feat_hash->{$other_feat}) {
                $processed{$other_feat} = 1;
                push @new_cluster, $other_feat;
            }
        }
        my $new_cluster_str = join ",", @new_cluster;
        $output_clusters->{$new_cluster_str} = 1;
    }
    return $output_clusters;
}
