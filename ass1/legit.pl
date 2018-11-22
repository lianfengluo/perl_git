#!/usr/bin/perl -w
use File::Compare;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use File::Find;
use File::Path 'rmtree';
use Algorithm::Diff;
use Algorithm::Merge qw(merge);
# Define the file that larger than 1MB as large file
my $LARGE_FILE_THRESHOLD = 1024 * 1024;
# A usage function
sub usage {
    print("Usage: legit.pl <command> [<args>]\n\n",
"These are the legit commands:\n",
"   init       Create an empty legit repository\n",
"   add        Add file contents to the index\n",
"   commit     Record changes to the repository\n",
"   log        Show commit log\n",
"   show       Show file at particular state\n",
"   rm         Remove files from the current directory and from the index\n",
"   status     Show the status of files in the current directory, index, and repository\n",
"   branch     list, create or delete a branch\n",
"   checkout   Switch branches or restore current directory files\n",
"   merge      Join two development histories together\n\n");
}
# check the whether did the first commit
sub check_commit {
    my $head_ref = get_file(".legit/.head", "legit.pl: error: head pointer\n");
    my $head_pointer = $head_ref->[0];
    if ($head_pointer == -1) {
        print STDERR "legit.pl: error: your repository does not have any commits yet\n";
        return 1;
    }
    return 0;
}

# input filename and err message return the @array reference
sub get_file {
    my ($filename, $err) = @_;
    $err = defined $err ? $err : "Cannot open file $filename\n";
    open my $f ,"<", $filename or die $err;
    my @arr = <$f>;
    close $f;
    return \@arr;
}
# input filename which is defined as large file and return the @array reference
sub get_file_large($) {
    my $filename = $_[0];
    $filename =~ m/([^\/]+?)$/;
    # get the large base filename
    my $large_file_name = ".legit/.large_base/$1";
    my $arr_ref = challenge_retrieve($large_file_name, $filename);
    return $arr_ref;
}
# input an array reference, a file name and err message to write the array into file 
sub write_file {
    my ($arr_ref, $filename, $err) = @_;
    $err = defined $err ? $err : "Cannot open file $filename\n";
    open my $f, ">", $filename or die $err;
    print $f @$arr_ref;
    close $f;
}
# input an variable, a file name and err to write the array into file 
sub write_file_variable {
    my ($text, $filename, $err) = @_;
    $err = defined $err ? $err : "Cannot open file $filename\n";
    open my $f, ">", $filename or die $err;
    print $f $text;
    close $f;
}
# input an variable, a file name and err to append the array into file 
sub write_file_variable_append {
    my ($text, $filename, $err) = @_;
    $err = defined $err ? $err : "Cannot open file $filename\n";
    open my $f, ">>", $filename or die $err;
    print $f $text;
    close $f;
}
# compare arrays function
# take two array reference
# return 1 if two array is different
sub compare_arrays($$) {
    my ($arr1, $arr2) = @_;
    # check the size of two array
    return 1 if (scalar (@$arr1) != scalar(@$arr2));
    # compare each line of two array
    foreach (0..$#$arr1) {
        return 1 if ($arr1->[$_] ne $arr2->[$_]);
    }
    return 0;
}

# Init function for initialization the .legit empty dir
# return 1 if error occur
sub init {
    # check whether this dir has been initialized or not
    if (-e ".legit" or -d ".legit") {
        # if the dir has been initialize
        print STDERR "legit.pl: error: .legit already exists\n";
        return 1;
    } else {
        # the first initialization
        mkdir(".legit");
    }
    # write the file or current branch
    my $current_branch = ".legit/.current_branch";
    # the init function will generate the first branch call master
    write_file_variable("master", $current_branch, "legit.pl: error: no .legit directory containing legit repository exists\n");
    my $branch = "master";
    my $branch_dir = ".legit/$branch/";
    mkdir $branch_dir if (!(-e $branch_dir and -d $branch_dir));
    # head file store the head pointer which is the newest commit number
    write_file_variable("-1", ".legit/.head", "legit.pl: error: cannot create head file\n");
    # set the master branch pointer point to 0 commit
    write_file_variable("-1", ".legit/$branch/.pointer", "legit.pl: error: cannot create pointer file\n");
    # project dir is the dir storing the commit files
    mkdir ".legit/.proj/" or die "legit.pl: error: Cannot create project dir\n";
    # the bottle two dir is for challenge
    # large dir is the dir also storing the commit files, but this file only contain large file's diff info
    mkdir ".legit/.large/" or die "legit.pl: error: Cannot create large project dir\n";
    # The large file base store the first the large store in commit
    mkdir ".legit/.large_base/" or die "legit.pl: error: Cannot create large project base dir\n";
    # The index dir is the dir that is used to store index(added files)
    mkdir ".legit/.index/" or die "legit.pl: error: Cannot create master branch index\n";
    mkdir ".legit/.proj/-1/" or die "legit.pl: error: Cannot create master branch index\n";
    mkdir ".legit/.large/-1/" or die "legit.pl: error: Cannot create master branch index\n";
    print("Initialized empty legit repository in .legit\n");
    return 0;
}

# show branch function
# return 1 if error occur
sub show_branch {
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the current branch
    my $branch_arr_ref = get_file(".legit/.current_branch", "Error branch\n");
    my $branch = $branch_arr_ref->[0];
    # show all the branch
    opendir $legit_dir, ".legit" or die "cannot open dir $dir: $!";
    foreach $dir (sort readdir($legit_dir)) {
        # only printing the dir that not start with .(which is branch)
        print ("$dir\n") if ($dir =~ /^[^\.]/);
    } 
    return 0;
}

# create branch function
# take one value which is branch name
# return 1 if error occur
sub branch {
    # check the legit is inited yet
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # create branch
    my $new_branch = $_[0];
    chomp $new_branch;
    my $branch_dir = ".legit/$new_branch";
    # check if the branch has been created
    if (!(-e $branch_dir and -d $branch_dir)) {
        mkdir $branch_dir or die "Cannot create new branch $new_branch\n";
        # get the current branch
        my $cur_branch_arr_ref = get_file(".legit/.current_branch", "Error branch\n");
        my $cur_branch = $cur_branch_arr_ref->[0];
        # copy current branch pointer to the new branch
        copy(".legit/$cur_branch/.pointer", ".legit/$new_branch/.pointer");
        # copy current branch index to new branch
        dircopy(".legit/.index", ".legit/.index");
        # base is the file for 3 way merge
        copy(".legit/$cur_branch/.pointer", ".legit/$new_branch/.base");
        # copy current branch log file
        copy(".legit/$cur_branch/log", ".legit/$new_branch/log");
    } else {
        print STDERR ("legit.pl: error: branch '$new_branch' already exists\n");
        return 1;
    }
}
# function for removing the branch
# take one value which is branch name
# return 1 if error occur
sub rm_branch {
    # check the legit is inited yet
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "Error branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    # get the branch is about to be remove
    my $rm_branch = $_[0];
    # if the current branch equal to remove branch
    if ($branch eq $rm_branch or $rm_branch eq "master") {
        print STDERR ("legit.pl: error: can not delete branch '$rm_branch'\n");
        return 1;
    } else {
        # the remove branch dir
        my $rm_branch_dir = ".legit/$rm_branch/";
        # check whether the branch is exist
        if (-e $rm_branch_dir and -d $rm_branch_dir) {
            # get branch pointer
            my $rm_branch_pointer = "$rm_branch_dir".".pointer";
            my $pointer_arr_ref = get_file($rm_branch_pointer);
            my $rm_pointer = $pointer_arr_ref->[0];
            my $cur_branch_pointer = ".legit/$branch/.pointer";
            $pointer_arr_ref = get_file($cur_branch_pointer);
            my $cur_pointer = $pointer_arr_ref->[0];
            # if the rm pointer has newer commit
            if ($rm_pointer > $cur_pointer) {
                print STDERR "legit.pl: error: branch '$rm_branch' has unmerged changes\n";
                return 1;
            }
            # remove the branch dir
            rmtree "$rm_branch_dir" or die "Cannot remove $rm_branch $!\n";
            print "Deleted branch '$rm_branch'\n";
        } else {
            print STDERR  ("legit.pl: error: branch '$rm_branch' does not exist\n");
            return 1;
        }
    }
    return 0;
}

# restore commit data to current dir and index dir
sub restore_info {
    my ($prev_dirname, $prev_dirname_large, $branch) = @_;
    # get the new branch pointer
    my $pointer_arr_ref = get_file(".legit/$branch/.pointer", "Error Stage\n");
    my $pointer = $pointer_arr_ref->[0];
    my %prev_dir_list;
    opendir $prev_dir, $prev_dirname or die "cannot open dir $prev_dirname: $!";
    opendir $prev_dir_large, $prev_dirname_large or die "cannot open dir $prev_dirname: $!";
    foreach (readdir($prev_dir)) {
        next if ($_ =~ /^\./);
        $prev_dir_list{$_} = 1 if (compare($prev_dirname.$_, $_) == 0 and 
        compare($prev_dirname.$_, ".legit/.index/$_") == 0);
    }
    foreach (readdir($prev_dir_large)) {
        next if ($_ =~ /^\./);
        $prev_dir_list{$_} = 1 if (-f $_ and -f ".legit/.index/$_" and challenge_cmp_one_large($_, $prev_dirname_large.$_) != 1 
        and challenge_cmp_one_large(".legit/.index/$_", $prev_dirname_large.$_) != 1 );
    }
    closedir $prev_dir;
    closedir $prev_dir_large;
    # restore the file in the branch commit
    my $restore_dir_name = ".legit/.proj/$pointer/";
    opendir $restore_dir, $restore_dir_name or die "cannot open dir $restore_dir_name: $!";
    my $restore_dir_name_large = ".legit/.large/$pointer/";
    opendir $restore_dir_large, $restore_dir_name_large or die "cannot open dir $restore_dir_name: $!";
    my @restore_files = ();
    my @restore_files_large = ();
    my %total_restore_dir;
    foreach (readdir($restore_dir)) {
        next if ($_ =~ /^[\.]/);
        $total_restore_dir{$_} = 1;
        push @restore_files, $_; 
    };
    foreach (readdir($restore_dir_large)) {
        next if ($_ =~ /^[\.]/);
        $total_restore_dir{$_} = 1;
        push @restore_files_large, $_;
    };
    closedir $restore_dir;
    closedir $restore_dir_large;
    opendir my $cur_dir, ".";
    foreach (readdir($cur_dir)) {
        unlink $_ if ($_ ne $0 and $_ ne "diary.txt" and ($total_restore_dir{$_} or 
        $prev_dir_list{$_}));
    }
    closedir ($cur_dir);
    opendir my $index_dir, ".legit/.index/";
    foreach (readdir($index_dir)) {
        unlink ".legit/.index/$_" if (".legit/.index/$_" ne "diary.txt" and ($total_restore_dir{$_} or 
        $prev_dir_list{$_}));
    }
    closedir ($index_dir);
    # restore the regular file
    foreach (@restore_files) {
        my $restore_file = $restore_dir_name.$_;
        copy($restore_file, './'.$_);
        copy($restore_file, '.legit/.index/'.$_);
    }
    # restore the large file
    foreach (@restore_files_large) {
        my $restore_file = $restore_dir_name_large.$_;
        my $restore_arr_ref = get_file_large($restore_file);
        write_file($restore_arr_ref, './'.$_, "Cannot write file $_\n");
        write_file($restore_arr_ref, '.legit/.index/'.$_, "Cannot write file $_\n");
    }
}
# checkout confliction
# take the files that did not commit
# take the restore name checkout will restore
# return 1 if override happen
sub check_override {
    my ($file_do_not_commit, $restore_dir_name, $restore_dir_name_large) = @_;
    my $index_file = '';
    my %conflit_files;
    foreach (keys %$file_do_not_commit) {
        my $restore_file = $restore_dir_name.$_;
        my $restore_file_large = $restore_dir_name_large.$_;
        my $index_file = ".legit/.index/$_";
        if (-f $restore_file and (compare($index_file, $restore_file) != 0 or compare($_, $restore_file) != 0)) {
            # check if the file in previous commit is the same as the current dir
            $conflit_files{$_} = 1;
        } elsif (-f $restore_file_large and ((-f $index_file and (challenge_cmp_one_large($index_file, $restore_file_large) == 1)) or 
                    (-f $_ and challenge_cmp_one_large($_, $restore_file_large) == 1))) {
            $conflit_files{$_} = 1;
        }
    }
    my @conflict_out = sort keys %conflit_files;
    if (@conflict_out) {
        print STDERR "legit.pl: error: Your changes to the following files would be overwritten by checkout:\n";
        my $conflict_text = join "\n", @conflict_out;
        print STDERR $conflict_text;
        print STDERR "\n";
        return 1;
    }
    return 0;
}
# get all the file names have not been committed
# take the commit dir
sub get_no_commit($$) {
    my ($commit_dir, $commit_dir_large) = @_;
    my $index_dir = ".legit/.index";
    my (%files, %files1, %file2, %files3);
    # get all the file in the cur dir
    opendir my $cur_dir, ".";
    foreach (readdir($cur_dir)) {
        $files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/);
    }
    closedir($cur_dir);
    # get all the file in the index dir
    find( sub { $files1{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $index_dir);
    # get all the file in the commit dir
    find( sub { $files2{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $commit_dir);
    # get all the file in the large commit dir
    find( sub { $files3{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $commit_dir_large);
    my %uniq;
    # get all the uniq filename in both folder
    foreach (keys %files) {
        $uniq{$_} = 1;
    }
    foreach (keys %files1) {
        $uniq{$_} = 1;
    }
    foreach (keys %files2) {
        $uniq{$_} = 1;
    }
    foreach (keys %files3) {
        $uniq{$_} = 1;
    }
    # diff two files in these two dirs with normal file
    my %no_commit_files;
    foreach (keys %uniq) {
        if ($files1{$_}) {
            if (-f $commit_dir_large."/".$_ and
                 challenge_cmp_one_large($index_dir."/".$_, $commit_dir_large."/".$_) != 1) {
                next;
            } elsif (-f $commit_dir."/".$_ and compare($commit_dir."/".$_, $index_dir."/".$_) == 0) {
                next;
            } else {
                $no_commit_files{$_} = 1;
            }
        }
        if ($files{$_}) {
            if (-f $commit_dir_large."/".$_ and
                 challenge_cmp_one_large($_, $commit_dir_large."/".$_) != 1) {
                next;
            } elsif (-f $commit_dir."/".$_ and compare($_, $commit_dir."/".$_) == 0) {
                next;
            } else {
                $no_commit_files{$_} = 1;
            }
        }
    }
    return \%no_commit_files;
}
# restore branch function
# take the branch name which need to restore, restore all restoring all the files in repo
sub restore_branch($) {
    my $branch = $_[0];
    # get the branch about to leave
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "Error branch\n");
    my $prev_branch = $cur_branch_arr_ref->[0];
    # get_previous pointer file
    my $prev_pointer_arr_ref = get_file(".legit/$prev_branch/.pointer", "Error pointer\n");
    my $prev_pointer = $prev_pointer_arr_ref->[0];
    my $prev_dirname = ".legit/.proj/$prev_pointer/";
    my $prev_dirname_large = ".legit/.large/$prev_pointer/";
    # the hash used to check the confliction
    # check the normal file confliction
    # get the new branch pointer
    my $pointer_arr_ref = get_file(".legit/$branch/.pointer", "Error Stage\n");
    my $pointer = $pointer_arr_ref->[0];
    # restore the file in the branch commit
    my $restore_dir_name = ".legit/.proj/$pointer/";
    my $restore_dir_name_large = ".legit/.large/$pointer/";
    # get the files that have not been committed
    my $file_do_not_commit = get_no_commit($prev_dirname, $prev_dirname_large);
    return 1 if (check_override($file_do_not_commit, $restore_dir_name, $restore_dir_name_large) == 1);
    restore_info($prev_dirname, $prev_dirname_large, $branch);
    write_file_variable($branch, ".legit/.current_branch", "Cannot get current branch\n");
    return 0;
}

# function for changing the branch
# retunr 1 if the error occur
sub checkout($) {
    # normal init check
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the new branch
    my $branch = $_[0];
    chomp $branch;
    my $branch_dir = ".legit/$branch";
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "Error branch\n");
    my $cur_branch = $cur_branch_arr_ref->[0];
    if($cur_branch eq $branch) {
        print STDERR "Already on '$cur_branch'\n";
        return 1;
    }
    if (!-d $branch_dir) {
        print STDERR "legit.pl: error: unknown branch '$branch'\n";
        return 1;
    }
    if (compare(".legit/$cur_branch/.pointer", ".legit/.head") == 0 and 
        compare(".legit/$branch/.pointer", ".legit/.head") == 0) {
        write_file_variable($branch, ".legit/.current_branch", "Cannot get current branch\n");
        print "Switched to branch '$branch'\n";
        return 0;
    }
    return 1 if (restore_branch($branch) == 1);
    print "Switched to branch '$branch'\n";
    return 0;
}

# show function, show the content in the index or committed file
sub show_func($) {
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    my $pointer = 0;
    my $file = '';
    # get the pointer and the filename need to be retrieved
    if ($_[0] =~ m/(.*):(.*)/) {
        $pointer = $1;
        $file = $2;
    } else {
        print STDERR "Invalid input\n";
        return 1;
    }
    my $sub_dir = '';
    my $index_dir = '';
    my $file_path = '';
    my $large_file_path = '';
    if ($pointer eq '') {
        my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
        my $cur_branch = $cur_branch_arr_ref->[0];
        $index_dir = ".legit/.index/";
        $file_path = ".legit/.index/$file";
        if (! -f $file_path) {
            print STDERR "legit.pl: error: '$file' not found in index\n";
            return 1;
        }
    } elsif ($pointer =~ /[0-9]/) {
        $sub_dir = ".legit/.proj/$pointer";
        $sub_dir_large = ".legit/.large/$pointer";
        $file_path = ".legit/.proj/$pointer/$file";
        $large_file_path = ".legit/.large/$pointer/$file";
        if (! -d $sub_dir and ! -d $sub_dir_large) {
            print STDERR "legit.pl: error: unknown commit '$pointer'\n";
            return 1;
        }
        if (! -f $file_path and ! -f $large_file_path) {
            print STDERR "legit.pl: error: '$file' not found in commit $pointer\n";
            return 1;
        }
    }
    if (-f $file_path) {
        # normal file
        my $arr_ref = get_file($file_path);
        print @$arr_ref;
    } else {
        # large file
        my $arr_ref = get_file_large($large_file_path);
        print @$arr_ref;
    }
    return 0;
}


# Add the file to the index dir
# return 1 if error occur
sub add {
    # normal check init
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get all the files need to be add
    my @filenames = @_;
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $cur_branch = $cur_branch_arr_ref->[0];
    my $dir = ".legit/.index/";
    my %add_list;
    # Update the content to the file which have already added
    if ($filenames[0] eq ".") {
        opendir $index_dir, $dir or die "cannot open dir $dir: $!";
        foreach (readdir($index_dir)) {
            next if $_ =~ /^\./;
            my $new_file_path = $dir.$_;
            if (-f $new_file_path and -f $_) {
                if (compare($_, $new_file_path) == 0) {
                    next;
                }
            }
            if (-f $_) {
                $add_list{$_} = 1;
                copy($_, $new_file_path);
            } else {
                if (-e $new_file_path and -f $new_file_path) {
                    # to remove the file in the index but not in the current dir
                    unlink ($new_file_path);
                }
            }
        }
        closedir ($index_dir);
    } else {
        # add the file in the command line
        my $exception = 0;
        foreach $filename (@filenames) {
            my $new_file_path = $dir.$filename;
            if (! -f $filename and !-f $new_file_path) {
                print STDERR "legit.pl: error: can not open '$filename'\n";
                return 1;
            }
        }
        foreach $filename (@filenames) {
            my $new_file_path = $dir.$filename;
            if (-f $new_file_path and -f $filename) {
                if (compare($filename, $new_file_path) == 0) {
                    next;
                }
            }
            if (-f $filename) {
                $add_list{$filename} = 1;
                copy($filename, $new_file_path);
            } else {
                if (-f $new_file_path) {
                    # to remove the file in the index but not in the current dir
                    unlink ($new_file_path);
                }
            }
        }
    }
    # record add action
    # this is the file that being used to check valid legit rm
    my $output_add = join "\n", keys %add_list;
    $output_add .= "\n";
    write_file_variable_append($output_add, ".legit/.index/.add");
    return 0;
}


# rm operation with "--cached flag"
sub rm_no_cached($$$$$) {
    my ($add_list_ref, $index_dir, $commit_dir, $commit_dir_large, $filenames_ref) = @_;
    foreach $filename (@$filenames_ref) {
        my $index_file = $index_dir.'/'.$filename;
        my $commit_file = $commit_dir.'/'.$filename;
        my $commit_file_large = $commit_dir_large.'/'.$filename;
        # check if exist in three folders
        if (-f $filename and -f $index_file and (-f $commit_file or -f $commit_file_large)) {
            if (compare($index_file, $filename) == 0) {
                if ($$add_list_ref{$filename}) {
                    print STDERR "legit.pl: error: '$filename' has changes staged in the index\n";
                    return 1;
                }
            } else {
                if (-f $commit_file and compare($index_file, $commit_file) != 0) {
                    # the normal compare
                    print STDERR "legit.pl: error: '$filename' in index is different to both working file and repository\n";
                    return 1;
                } elsif (-f $commit_file_large and challenge_cmp_one_large($index_file, $commit_file_large) == 1) {
                    # the large file compare
                    print STDERR "legit.pl: error: '$filename' in index is different to both working file and repository\n";
                    return 1;
                } else {
                    print STDERR "legit.pl: error: '$filename' in repository is different to working file\n";
                    return 1;
                }
            }
        } else {
            # if not exist in three folders
            if (!(-e $index_file and -f $index_file)) {
                # check the is the file had been added
                print STDERR "legit.pl: error: '$filename' is not in the legit repository\n";
                return 1;
            } else {
                # check the file is added the index but not been committed
                if ($$add_list_ref{$filename}) {
                    print STDERR "legit.pl: error: '$filename' has changes staged in the index\n";
                    return 1;
                }
                print STDERR "legit.pl: error: '$filename' in repository is different to working file\n";
                return 1;
            }
        }
    }
    foreach $filename (@$filenames_ref) {
        my $index_file = $index_dir.'/'.$filename;
        my $commit_file = $commit_dir.'/'.$filename;
        my $commit_file_large = $commit_dir_large.'/'.$filename;
        if (-f $filename  and -f $index_file and (-f $commit_file or -f $commit_file_large) 
            and compare($index_file, $filename) == 0) {
            unlink $index_file;
            unlink $filename;
        }
    }
    return 0;
}

# rm operation with "--cached" flag
sub rm_cached($$$$) {
    my ($index_dir, $commit_dir, $commit_dir_large, $filenames_ref) = @_;
    # this loop is to use check whether the file is valide to be removed
    foreach $filename (@$filenames_ref) {
        my $index_file = $index_dir.'/'.$filename;
        my $commit_file = $commit_dir.'/'.$filename;
        my $commit_file_large = $commit_dir_large.'/'.$filename;
        # check if exist in three folders
        if (-f $index_file) {
            # check is the index file match the index file or committed file
            if (compare($index_file, $filename) == 0) {
                next;
            } elsif (-f $commit_file) {
                next if (compare($index_file, $commit_file) == 0);
            } elsif (-f $commit_file_large) {
                next if (challenge_cmp_one_large($index_file, $commit_file_large) != 1);
            }
            print STDERR "legit.pl: error: '$filename' in index is different to both working file and repository\n";
            return 1;
        } else {
            print STDERR "legit.pl: error: '$filename' is not in the legit repository\n";
            return 1;
        }
    }
    # remove operation loop
    foreach $filename (@$filenames_ref) {
        my $index_file = $index_dir.'/'.$filename;
        my $commit_file = $commit_dir.'/'.$filename;
        my $commit_file_large = $commit_dir_large.'/'.$filename;
        # check if exist in three folders
        if (-f $index_file) {
            if (compare($index_file, $filename) == 0) {
                unlink $index_file;
            } elsif (-f $commit_file) {
                unlink $index_file if (compare($index_file, $commit_file) == 0);
            } elsif (-f $commit_file_large) {
                unlink $index_file if (challenge_cmp_one_large($index_file, $commit_file_large) != 1);
            }
        }
    }
    return 0;
}

# remove the file with checking
# return 1 if the error occur
sub rm {
    # check the initialization
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get all the remove files
    my @filenames = @_;
    # check whether is a cached rm
    my $cached = 0;
    # check whether it only remove the index
    if (lc($filenames[0]) eq "--cached") {
        $cached = 1;
        shift @filenames;
    }
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    # get the current branch pointer
    my $pointer_ref = get_file(".legit/$branch/.pointer", "legit.pl: error: current branch\n");
    my $pointer = $pointer_ref->[0];
    my $commit_dir = ".legit/.proj/$pointer";
    my $commit_dir_large = ".legit/.large/$pointer";
    # go to current branch folder
    my $index_dir = ".legit/.index";
    my %add_list;
    my $add_file = ".legit/.index/.add";
    if (-e $add_file and -f $add_file) {
        open my $add_f, "<", $add_file;
        my @add_f_arr = <$add_f>;
        foreach (@add_f_arr) {
            chomp $_;
            $add_list{$_} = 1;
        }
        close $add_f;
    }
    if (!$cached) {
        return 1 if (rm_no_cached(\%add_list, $index_dir, $commit_dir, $commit_dir_large, \@filenames) == 1);
    } else {
        # delete index(cached only)
        return 1 if (rm_cached($index_dir, $commit_dir, $commit_dir_large, \@filenames) == 1);
    }
    return 0;
}

# remove the file with force flag
# return 1 if error occur
sub rm_force {
    # normal check
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    my @filenames = @_;
    my $cached = 0;
    if (lc($filenames[0]) eq "--cached") {
        $cached = 1;
        shift @filenames;
    }
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    my $add_dir = ".legit/.index";
    foreach $filename (@filenames) {
        my $index_file = $add_dir.'/'.$filename;
        if (!(-f $index_file)) {
            print STDERR "legit.pl: error: '$filename' is not in the legit repository\n";
            return 1;
        }
    }
    foreach $filename (@filenames) {
        my $index_file = $add_dir.'/'.$filename;
        if (!(-e $index_file and -f $index_file)) {
            print STDERR "legit.pl: error: '$filename' is not in the legit repository\n";
            next;
        }
        unlink $index_file if (-e $index_file and -f $index_file);
        if ($cached) {
            next;
        } else {
            unlink $filename if (-e $filename and -f $filename);
        }
    }
    return 0;
}


# function check the content difference
# the first argment is the index dir name
# the second argment is the commit dir name
# the third argment is the large commit dir name
# return 1 if error occur
sub check_diff($$$) {
    # normal check init
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    my ($index_dir, $commit_dir, $commit_dir_large) = (@_);
    return 1 if (!-d $commit_dir and !-d $commit_dir_large);
    my (%files1, %files2, %file3);
    # get all the file in the index dir
    find( sub { $files1{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $index_dir);
    # get all the file in the commit dir
    find( sub { $files2{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $commit_dir);
    # get all the file in the large commit dir
    find( sub { $files3{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, $commit_dir_large);
    my %uniq;
    # get all the uniq filename in both folder
    foreach (keys %files1) {
        $uniq{$_} = 1;
    }
    foreach (keys %files2) {
        $uniq{$_} = 1;
    }
    foreach (keys %files3) {
        $uniq{$_} = 1;
    }
    # diff two files in these two dirs with normal file
    foreach (keys %uniq) {
        if ($files1{$_} and ($files2{$_} or $files3{$_})) {
            if (-f $commit_dir_large."/".$_ and
                 challenge_cmp_one_large($index_dir."/".$_, $commit_dir_large."/".$_) != 1) {
                next;
            } elsif (-f $commit_dir."/".$_ and compare($commit_dir."/".$_, $index_dir."/".$_) == 0) {
                next;
            } else {
                return 1;
            }
        } elsif($files1{$_} and (!$files2{$_} and !$files3{$_})) {
            return 1;
        } elsif(!$files1{$_} and ($files2{$_} or $files3{$_})) {
            return 1;
        }
    }
    return 0;
}


# commit the changed file
sub commit($$) {
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    # check the file is added or not
    if (!(-d ".legit/.index/")) {
        print STDERR "nothing to commit\n";
        return 1;
    }
    my ($comment, $is_check) = @_;
    my $pointer = -1;
    # get the lattest pointer
    my $head_ref = get_file(".legit/.head", "legit.pl: error: head pointer\n");
    $head = $head_ref->[0];
    my $pointer_ref = get_file(".legit/$branch/.pointer", "legit.pl: error: head pointer\n");
    $pointer = $pointer_ref->[0];
    my $commit_dir = ".legit/.proj/$pointer";
    my $commit_dir_large = ".legit/.large/$pointer";
    if ($is_check == 2) {
        add(".");
    }
    if (($is_check == 1 or $is_check == 2) and check_diff(".legit/.index", $commit_dir, $commit_dir_large) == 0) {
        print STDERR "nothing to commit\n";
        return 1;
    }
    $head++;
    $commit_dir = ".legit/.proj/$head";
    $commit_dir_large = ".legit/.large/$head";
    mkdir $commit_dir;
    mkdir $commit_dir_large;
    write_file_variable($head, ".legit/.head", "Error head pointer file\n");
    write_file_variable($head, ".legit/$branch/.pointer", "Error branch pointer file\n");
    # update log file
    my $log = ".legit/$branch/log";
    my $new_line = $head." ".$comment."\n";
    write_file_variable_append($new_line, $log);
    my $added_dir_name = ".legit/.index";
    opendir $added_dir, $added_dir_name or die $!;
    while (my $file = readdir($added_dir)) {
        my $index_file = $added_dir_name."/$file";
        if (-f $index_file and !($file =~ /^\./) and (-s $index_file) >= $LARGE_FILE_THRESHOLD) {
            # if this is a large file
            if (! -f ".legit/.large_base/$file") {
                # the first time add this large file
                copy($index_file, ".legit/.large_base/$file") or die "Copy failed: $!\n";
            }
            my $diff_arr_text = challenge_store(".legit/.large_base/$file", $index_file);
            # storing the diff info
            write_file_variable($diff_arr_text, $commit_dir_large."/$file");
        } elsif(-f $index_file and !($file =~ /^\./)) {
            # normal commit
            copy($index_file, $commit_dir."/$file") or die "Copy failed: $!\n";
        }
    }
    unlink ".legit/.index/.add" if (-f ".legit/.index/.add");
    closedir ($added_dir);
    print ("Committed as commit $head\n");
    return 0;
}

# read log function
# return 1 if error occur
sub read_log {
    # normal checking init
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    my $log = ".legit/$branch/log";
    my $arr_ref = get_file($log, "legit.pl: error: your repository does not have any commits yet\n");
    if (@$arr_ref) {
        print(reverse(@$arr_ref));
    } else {
        print STDERR ("legit.pl: error: your repository does not have any commits yet\n");
        return 1;
    }
    return 0;
}

# status function
sub status {
    # normal checking init
    if (!(-e ".legit/" or -d ".legit/")) {
        print STDERR "legit.pl: error: no .legit directory containing legit repository exists\n" ;
        return 1;
    }
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $branch = $cur_branch_arr_ref->[0];
    my $pointer = 0;
    # get the branch
    my $pointer_ref = get_file(".legit/$branch/.pointer", "legit.pl: error: branch pointer\n");
    $pointer = $pointer_ref->[0];
    my $index_dir = ".legit/.index/";
    # get all the file name
    my %file_list;
    opendir $i_d, $index_dir or die "cannot open dir $index_dir: $!";
    foreach (readdir($i_d)) {
        next if ($_ =~ /^\./);
        my $index_file = $index_dir."$_";
        $file_list{$_} = 1 if (-e $index_file and -f $index_file);
    }
    closedir $i_d;
    my $commit_dir = ".legit/.proj/$pointer/";
    opendir $c_d,  $commit_dir or die "cannot open dir $commit_dir: $!";
    foreach (readdir($c_d)) {
        next if ($_ =~ /^\./);
        my $commit_file = $commit_dir."$_";
        $file_list{$_} = 1 if (-f $commit_file);
    }
    closedir $c_d;
    my $commit_dir_large = ".legit/.large/$pointer/";
    opendir $c_d_l,  $commit_dir_large or die "cannot open dir $commit_dir_large: $!";
    foreach (readdir($c_d_l)) {
        next if ($_ =~ /^\./);
        my $commit_file_large = $commit_dir_large."$_";
        $file_list{$_} = 1 if (-f $commit_file_large);
    }
    closedir $c_d_l;
    opendir $cur_dir, "." or die "cannot open dir $cur_dir: $!";
    foreach (readdir($cur_dir)) {
        next if ($_ =~ /^\./);
        $file_list{$_} = 1 if (-f $_);
    }
    closedir $cur_dir;
    foreach (sort keys %file_list) {
        my $commit_file = $commit_dir."$_";
        my $commit_file_large = $commit_dir_large."$_";
        my $index_file = $index_dir."$_";
        if ((-e $index_file and -f $index_file) and (-e $_ and -f $_) and !(-f $commit_file or -f $commit_file_large)) {
            print "$_ - added to index\n";
            next;
        }
        if (!(-e $index_file and -f $index_file) and (-e $_ and -f $_)) {
            print "$_ - untracked\n";
            next;
        }
        if (!(-e $_ and -f $_) and !(-e $index_file and -f $index_file) and (-f $commit_file or -f $commit_file_large)) {
            print "$_ - deleted\n";
            next;
        }
        if ((-e $index_file and -f $index_file) and !(-e $_ and -f $_) and (-f $commit_file or -f $commit_file_large)) {
            print "$_ - file deleted\n";
            next;
        }
        if (-f $commit_file and compare($commit_file, $_) == 0) {
            print "$_ - same as repo\n";
            next;
        } elsif (-f $commit_file_large and challenge_cmp_one_large($_, $commit_file_large) == 0) {
            print "$_ - same as repo\n";
            next;
        }
        # the file must exist in current dir
        # if commit file is regular file
        if (-f $commit_file) {
            if (compare($index_file, $_) != 0 and compare($index_file, $commit_file) != 0) {
                print "$_ - file changed, different changes staged for commit\n";
            } elsif (compare($index_file, $commit_file) == 0 and compare($_, $index_file) != 0) {
                print "$_ - file changed, changes not staged for commit\n";
            } elsif (compare($index_file, $commit_file) != 0) {
                print "$_ - file changed, changes staged for commit\n";
            }
        }
        # if commit file is large file
        if (-f $commit_file_large) {
            if (compare($index_file, $_) != 0 and challenge_cmp_one_large($index_file, $commit_file_large) != 0) {
                print "$_ - file changed, different changes staged for commit\n";
            } elsif (challenge_cmp_one_large($index_file, $commit_file_large) == 0 and compare($_, $index_file) != 0) {
                print "$_ - file changed, changes not staged for commit\n";
            } elsif (challenge_cmp_one_large($index_file, $commit_file_large) != 0) {
                print "$_ - file changed, changes staged for commit\n";
            }
        }
    }
    return 0;
}

# resolve conflict function
# three way conflict
# take three arr_ref
# resolve the conflict of three array
# return an array reference after resolve
sub resolve_conflict($$$) {
    my ($base_ref, $merge_ref, $cur_ref) = @_;
    my @resolve_arr = ();
    return \@resolve_arr if (scalar @$merge_ref == 0 and scalar @$cur_ref == 0);
    @resolve_arr = merge($base_ref, $merge_ref, $cur_ref);
    return \@resolve_arr;
}
# check conflict function
# three way conflict
# take three arr_ref
# check the confliction
# return 1 if conflict occur
sub check_conflict($$$) {
    my ($base_ref, $merge_ref, $cur_ref) = @_;
    my $conflict = 0;
    merge($base_ref, $merge_ref, $cur_ref, { 
              CONFLICT => sub { $conflict = 1; } 
    });
    return $conflict;
}

# merge the log file when merge branch
# take two branch name
# the first branch is current branch name
# the second branch is the merge branch name
sub merge_log($$) {
    # merge log file
    my ($cur_branch, $merge_branch) = @_;
    my %new_log;
    open my $cur_log_f, "<", ".legit/$cur_branch/log";
    open my $merge_log_f, "<", ".legit/$merge_branch/log";
    my @cur_log_arr = <$cur_log_f>;
    my @merge_log_arr = <$merge_log_f>;
    close $cur_log_f;
    close $merge_log_f;
    my $cur_log_p = 0;
    my $merge_log_p = 0;
    while ($cur_log_p != scalar @cur_log_arr and $merge_log_p != scalar @merge_log_arr) {
        if ($cur_log_arr[$cur_log_p] lt $merge_log_arr[$merge_log_p]) {
            $new_log{$cur_log_arr[$cur_log_p]} = 1;
            $cur_log_p++;
        } else {
            $new_log{$merge_log_arr[$merge_log_p]} = 1;
            $merge_log_p++;
        }
    }
    while ($cur_log_p != scalar @cur_log_arr) {
        $new_log{$cur_log_arr[$cur_log_p]} = 1;
        $cur_log_p++;
    }
    while ($merge_log_p != scalar @merge_log_arr) {
        $new_log{$merge_log_arr[$merge_log_p]} = 1;
        $merge_log_p++;
    }
    open $cur_log_f, ">", ".legit/$cur_branch/log";
    print $cur_log_f sort keys %new_log;
    close $cur_log_f;
}
# check the confliction
# take the arr reference that include all the filename
# the regular and large base, merge, current dir
# return the reference files that are conflicted
sub check_confliction {
    my ($all_files_ref, $base_dir, $base_dir_large, $merge_commit_dir, $merge_commit_dir_large, $cur_commit_dir, $cur_commit_dir_large) = @_;
    my @err_files = ();
    foreach (sort @$all_files_ref) {
        my $base_file = $base_dir.$_;
        my $base_file_large = $base_dir_large.$_;
        my $large_base = (-f $base_file_large) ? 1 : 0;
        my $merge_file = $merge_commit_dir.$_;
        my $merge_file_large = $merge_commit_dir_large.$_;
        my $large_merge = (-f $merge_file_large) ? 1 : 0;
        my $cur_file = $cur_commit_dir.$_;
        my $cur_file_large = $cur_commit_dir_large.$_;
        my $large_cur = (-f $cur_file_large) ? 1 : 0;
        if ((-f $merge_file or -f $merge_file_large) and (-f $cur_file or -f $cur_file_large)) {
            # text conflict checking
            # check the combination
            my ($base_arr, $merge_arr, $cur_arr);
            if ($large_cur == 0) {
                $cur_arr = get_file($cur_file);
            } else {
                $cur_arr = get_file_large($cur_file_large);
            }
            if ($large_merge == 0) {
                $merge_arr = get_file($merge_file);
            } else {
                $merge_arr = get_file_large($merge_file_large);
            }
            if (!-f $base_file and !-f $base_file_large) {
                my @arr = ();
                $base_arr = \@arr;
            } elsif ($large_base == 0) {
                $base_arr = get_file($base_file);
            } else {
                $base_arr = get_file_large($base_file_large);
            }
            next if (compare_arrays($base_arr, $merge_arr) == 0 and compare_arrays($merge_arr, $cur_arr) == 0);
            push @err_files, $_ if (check_conflict($base_arr, $merge_arr, $cur_arr) == 1);
        } elsif ((-f $base_file or -f $base_file_large) and (-f $merge_file or -f $merge_file_large)) {
            # delete conflict
            push @err_files, $_;
        } elsif ((-f $base_file or -f $base_file_large) and (-f $cur_file or -f $cur_file_large)) {
            # delete conflict
            push @err_files, $_;
        }
    }
    return \@err_files;
}
# merge the content function
# take the arr reference that include all the filename
# the regular and large base, merge, current dir, and current branch
# writing the content after merge
sub merge_operation {
    my ($all_files_ref, $base_dir, $base_dir_large, $merge_commit_dir, 
    $merge_commit_dir_large, $cur_commit_dir, $cur_commit_dir_large, $cur_branch) = @_;
    foreach (sort @$all_files_ref) {
        my $base_file = $base_dir.$_;
        my $base_file_large = $base_dir_large.$_;
        my $large_base = (-f $base_file_large) ? 1 : 0;
        my $merge_file = $merge_commit_dir.$_;
        my $merge_file_large = $merge_commit_dir_large.$_;
        my $large_merge = (-f $merge_file_large) ? 1 : 0;
        my $cur_file = $cur_commit_dir.$_;
        my $cur_file_large = $cur_commit_dir_large.$_;
        my $large_cur = (-f $cur_file_large) ? 1 : 0;
        my $index_file = ".legit/.index/$_";
        if ((-f $cur_file or -f $cur_file_large) and !(-f $merge_file or -f $merge_file_large)
         and (!(-f $base_file or -f $base_file_large))) {
            if ($large_cur == 0) {
                copy($cur_file, $index_file);
                copy($cur_file, $_);
            } else {
                my $cur_large_arr_ref = get_file_large($cur_file_large);
                write_file($cur_large_arr_ref, $index_file);
                write_file($cur_large_arr_ref, $_);
            }
        } elsif ((-f $merge_file or -f $merge_file_large) and !(-f $cur_file or -f $cur_file_large)
         and (!(-f $base_file or -f $base_file_large))) {
            if ($large_merge == 0) {
                copy($merge_file, $index_file);
                copy($merge_file, $_);
            } else {
                my $merge_large_arr_ref = get_file_large($merge_file_large);
                write_file($merge_large_arr_ref, $index_file);
                write_file($merge_large_arr_ref, $_);
            }
        }  else {
            my ($base_arr, $merge_arr, $cur_arr);
            if ((! -f $cur_file and ! -f $cur_file_large)) {
                my @arr1 = ();
                $cur_arr = \@arr1;
            } elsif ($large_cur == 0) {
                $cur_arr = get_file($cur_file);
            } else {
                $cur_arr = get_file_large($cur_file_large);
            }
            if (! -f $merge_file and ! -f $merge_file_large) {
                my @arr2 = ();
                $merge_arr = \@arr2;
            } elsif ($large_merge == 0) {
                $merge_arr = get_file($merge_file);
            } else {
                $merge_arr = get_file_large($merge_file_large);
            }
            if (! -f $base_file and ! -f $base_file_large) {
                my @arr3 = ();
                $base_arr = \@arr3;
            } elsif ($large_base == 0) {
                $base_arr = get_file($base_file);
            } else {
                $base_arr = get_file_large($base_file_large);
            }
            # next if (compare_arrays($base_arr, $merge_arr) == 0 and compare_arrays($base_arr, $cur_arr) == 0);
            if ((-f $base_file and (compare_arrays($base_arr, $merge_arr) != 0 and compare_arrays($base_arr, $cur_arr) != 0)) 
            or ! -f $base_file) {
                my $out_arr_ref = resolve_conflict($base_arr, $merge_arr, $cur_arr);
                write_file($out_arr_ref, $_);
                copy($_, $index_file);
                print "Auto-merging $_\n";
            } else {
                my $out_arr_ref = resolve_conflict($base_arr, $merge_arr, $cur_arr);
                write_file($out_arr_ref, $_);
                copy($_, $index_file);
                next;
            }
        }
    }
}
# merge function
# take the merge branch, merge flag and merge message
sub merge_function {
    my ($merge_branch, $flag, $message) = @_;
    if ($flag ne "-m" and $merge_branch ne "-m") {
        return 1;
    } elsif ($flag ne "-m") {
        # the message is in flag position, branch is in message position
        ($message, $flag) = ($flag, $message);
        # the branch is in flag position, flag is in branch position
        ($flag, $merge_branch) = ($merge_branch, $flag);
    }
    my $merge_branch_dir = ".legit/$merge_branch/";
    if (!(-d $merge_branch_dir)) {
        print STDERR "legit.pl: error: unknown branch '$merge_branch'\n";
        return 1;
    }
    # get merge branch pointer
    my $merge_pointer_file = ".legit/$merge_branch/.pointer";
    # get current branch
    # get the current branch
    my $cur_branch_arr_ref = get_file(".legit/.current_branch", "legit.pl: error: current branch\n");
    my $cur_branch = $cur_branch_arr_ref->[0];
    # get the current branch pointer
    my $cur_pointer_file = ".legit/$cur_branch/.pointer";
    my $cur_pointer_arr_ref = get_file($cur_pointer_file, "legit.pl: error: pointer\n");
    my $cur_pointer = $cur_pointer_arr_ref->[0];
    # get the merge branch pointer
    my $message_branch_file = ".legit/$merge_branch/.pointer";
    my $merge_branch_arr_ref = get_file($message_branch_file, "legit.pl: error: pointer\n");
    my $merge_pointer = $merge_branch_arr_ref->[0];
    # the current pointer is the same as the current branch pointer
    if (compare(".legit/$cur_branch/.pointer", ".legit/$merge_branch/.pointer") == 0) {
        # when the merge branch at the lastest pointer
        # or if two branch is the same
        print "Already up to date\n";
        return 0;
    } elsif (compare(".legit/$merge_branch/.base", ".legit/$cur_branch/.pointer") == 0) {
        # perform fast forward
        copy($merge_pointer_file, $cur_pointer_file);
        copy(".legit/$merge_branch/.pointer", ".legit/$merge_branch/.base");
        merge_log($cur_branch, $merge_branch);
        return 1 if (restore_branch($cur_branch) == 1);
        print "Fast-forward: no commit created\n";
        return 0;
    } 
    # get the base pointer
    my $merge_base_f = ".legit/$merge_branch/.base";
    my $merge_base_arr_ref = get_file($merge_base_f, "legit.pl: error: pointer\n");
    my $merge_base = $merge_base_arr_ref->[0];
    # Three way merge
    # commit dir
    my $cur_commit_dir = ".legit/.proj/$cur_pointer/";
    my $merge_commit_dir = ".legit/.proj/$merge_pointer/";
    my $base_dir = ".legit/.proj/$merge_base/";
    # large commit dir
    my $cur_commit_dir_large = ".legit/.large/$cur_pointer/";
    my $merge_commit_dir_large = ".legit/.large/$merge_pointer/";
    my $base_dir_large = ".legit/.large/$merge_base/";
    my %all_files;
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$cur_commit_dir");
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$merge_commit_dir");
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$base_dir");
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$cur_commit_dir_large");
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$merge_commit_dir_large");
    find( sub { $all_files{$_} = 1 if (-f $_ and $_ =~ /^[^\.]/)}, "$base_dir_large");
    my @all_files_arr = keys %all_files;
    my $err_files_ref = check_confliction(\@all_files_arr, $base_dir, $base_dir_large, $merge_commit_dir, $merge_commit_dir_large, 
	$cur_commit_dir, $cur_commit_dir_large);
    if (@$err_files_ref) {
        print STDERR "legit.pl: error: These files can not be merged:\n";
        my $err_out = join "\n", sort @$err_files_ref;
        print STDERR "$err_out\n";
        return 1;
    }
    merge_operation(\@all_files_arr, $base_dir, $base_dir_large, $merge_commit_dir, $merge_commit_dir_large, 
	$cur_commit_dir, $cur_commit_dir_large, $cur_branch);
    commit($message, 0);
    merge_log($cur_branch, $merge_branch);
    copy(".legit/$merge_pointer/.pointer", ".legit/$merge_pointer/.base");
    return 0;
}


# challenge function

# take two filename as variable
# the first filename is the normal file
# the second filename is the file store the diff info
# return 1 if two file is the same
# return nothing if two file is the different
sub challenge_cmp_one_large($$) {
    my ($org_file, $diff_file) = @_;
    my $org_file_ref_arr = get_file($org_file);
    my $diff_file_ref_arr = get_file_large($diff_file);
    return compare_arrays($org_file_ref_arr, $diff_file_ref_arr);
}
# take two filename as variable
# the first filename is the file store the diff info
# the second filename is the file store the diff info
# return 1 if two file is the same
# return nothing if two file is the different
sub challenge_cmp_two_large($$) {
    my ($diff_file1, $diff_file2) = @_;
    my $diff_file_ref_arr1 = get_file_large($diff_file1);
    my $diff_file_ref_arr2 = get_file_large($diff_file2);
    return compare_arrays($diff_file_ref_arr1, $diff_file_ref_arr2);
}
# a function base on the diff info to retrieve the info
# Take the base filename
# Take the diff info filename
# return an array reference which is restore by these two files
sub challenge_retrieve($$) {
    my ($filename1, $filename2) = @_;
    open my $f1, "<", $filename1;
    open my $f2, "<", $filename2;
    my @file1 = <$f1>;
    my @file2 = <$f2>;
    close $f1;
    close $f2;
    my @restore_f = ();
    my $f1_p = 0;
    my $f2_p = 0;
    while ($f2_p != scalar @file2 and $f1_p != scalar @file1) {
        if ($file2[$f2_p] =~ m/(-?[0-9]+),(-?[0-9]+)d/) {
            # delete operation
            while ($f1_p < $1) {
                push @restore_f, $file1[$f1_p];
                $f1_p++;
            }
            while ($f1_p <= $2) {
                $f1_p++;
            }
            # move the next diff
            $f2_p++;
        } elsif ($file2[$f2_p] =~ m/(-?[0-9]+)a([0-9]+)/) {
            # append operation
            my $gap = $2;
            while ($f1_p < $1 + 1) {
                push @restore_f, $file1[$f1_p];
                $f1_p++;
            }
            $f2_p++;
            foreach ($f2_p..($f2_p + $gap)) {
                push @restore_f, $file2[$_];
            }
            # move the next diff
            $f2_p += ($gap + 1);
        } elsif ($file2[$f2_p] =~ m/(-?[0-9]+),(-?[0-9]+)c([0-9]+)/) {
            # conflict operation
            while ($f1_p < $1) {
                push @restore_f, $file1[$f1_p];
                $f1_p++;
            }
            while ($f1_p <= $2) {
                $f1_p++;
            }
            $f2_p++;
            my $gap = $3;
            foreach ($f2_p..($f2_p + $gap)) {
                push @restore_f, $file2[$_];
            }
            # move the next diff
            $f2_p += ($gap + 1);
        }
    }
    while ($f1_p != scalar @file1) {
        push @restore_f, $file1[$f1_p];
        $f1_p++;
    }
    return \@restore_f;
}

# take two filenames
# the first file is the file we will store in the large base
# the second file is the changed file which we will only get the diff
sub challenge_store($$) {
    my ($filename1, $filename2) = @_;
    open my $f1, "<", $filename1;
    open my $f2, "<", $filename2;
    my @file1 = <$f1>;
    my @file2 = <$f2>;
    close $f1;
    close $f2;
    my $temp_text = '';
    my $diff = Algorithm::Diff->new( \@file1, \@file2 );
    #$diff->Base( 1 );   # Return line numbers, not indices
    while($diff->Next()) {
        # if two line is the same
        next if $diff->Same();
        if(! $diff->Items(2)) {
            # delete diff
            $temp_text .= $diff->Get(Min1).",".$diff->Get(Max1)."d\n";
        } elsif(! $diff->Items(1)) {
            # append diff
            my $gap = $diff->Get(Max2) - $diff->Get(Min2);
            $temp_text .= $diff->Get(Max1)."a".$gap."\n";
        } else {
            # conflict diff
            my $gap = $diff->Get(Max2) - $diff->Get(Min2);
            $temp_text .= $diff->Get(Min1).",".$diff->Get(Max1)."c".$gap."\n";
        }
        $temp_text.="$_" for $diff->Items(2);
    }
    return $temp_text;
}
if (scalar @ARGV == 0) {
    usage();
    exit 1;
}

# init entry
if (lc($ARGV[0]) eq "init") {
    exit 1 if (init() == 1);
    exit 0;
}
# add entry
if (lc($ARGV[0]) eq "add") {
    if (scalar @ARGV < 2) {
        print STDERR "legit.pl add file1 file2 ...\n";
        exit 1;
    }
    exit 1 if (add(@ARGV[1..$#ARGV]) == 1);
    exit 0;
}
# log entry
if (lc($ARGV[0]) eq "log") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV != 1) {
        print STDERR "legit.pl log\n";
        exit 1;
    }
    exit 1 if (read_log() == 1);
    exit 0;
}

# show entry
if (lc($ARGV[0]) eq "show") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV != 2) {
        print STDERR "legit.pl show commit:filename\n";
        exit 1;
    }
    exit 1 if (show_func($ARGV[1]) == 1);
    exit 0;
}
# commit entry
if (lc($ARGV[0]) eq "commit") {
    if ($ARGV[1] eq "-m") {
        exit 1 if (commit($ARGV[2], 1) == 1);
    } elsif ($ARGV[1] eq "-a" and $ARGV[2] eq "-m") {
        exit 1 if (commit($ARGV[3], 2) == 1);
    } else {
        print("legit.pl commit [-a] -m message\n");
        exit 1;
    }
    exit 0;
}
# rm entry
if (lc($ARGV[0]) eq "rm") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV < 2) {
        print STDERR "legit.pl rm [--force] [--cached] filenames\n";
        exit 1;
    }
    my %input_list;
    foreach (@ARGV) {
        $input_list{$_} = 1;
    }
    if ($input_list{"--force"} and $input_list{"--cached"}) {
        $ARGV[2] = "--cached";
        exit 1 if (rm_force(@ARGV[2..$#ARGV]) == 1);
    } elsif ($input_list{"--force"}) {
        exit 1 if (rm_force(@ARGV[2..$#ARGV]) == 1);
    } else {
        exit 1 if (rm(@ARGV[1..$#ARGV]) == 1);
    }
    exit 0;
}
# status entry
if (lc($ARGV[0]) eq "status") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV != 1) {
        print STDERR "legit.pl status\n";
        exit 1;
    }
    exit 1 if (status() == 1);
    exit 0;
}
# branch entry
if (lc($ARGV[0]) eq "branch") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV != 1 and scalar @ARGV != 2 and scalar @ARGV != 3) {
        print STDERR "legit.pl branch [-d] [branch-name]\n",
            "legit.pl branch either creates a branch, deletes a branch or lists current branch names. \n";
        exit 1;
    }
    if (scalar @ARGV == 1) {
        # show branch
        exit 1 if (show_branch() == 1);
    } elsif (lc($ARGV[1]) eq "-d" and scalar @ARGV == 3) {
        # remove branch
        exit 1 if (rm_branch($ARGV[2]) == 1);
    } elsif (scalar @ARGV == 2) {
        # create branch
        exit 1 if (branch($ARGV[1]) == 1);
    }
    exit 0;
}
# checkout entry
if (lc($ARGV[0]) eq "checkout") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV != 2) {
        print STDERR "legit.pl checkout branch-name\n";
        exit 1;
    }
    exit 1 if (checkout($ARGV[1]) == 1);
    exit 0;
}

# merge entry
if (lc($ARGV[0]) eq "merge") {
    # check whether the legit did the commit yet
    exit 1 if(check_commit() == 1);
    if (scalar @ARGV == 1) {
        print STDERR "usage: legit.pl merge <branch|commit> -m message\n";
        exit 1; 
    }
    my $i = 0;
    while ($i != (scalar @ARGV)) {
        if ($ARGV[$i] ne "-m") {
            $i++;
        } else {
            last;
        }
    }
    if ($i == (scalar @ARGV)) {
        print STDERR "legit.pl: error: empty commit message\n";
        exit 1;
    } elsif (scalar @ARGV != 4) {
        print STDERR "legit.pl merge branch-name|commit -m message\n";
        exit 1;
    }
    shift @ARGV;
    exit 1 if (merge_function(@ARGV) == 1);
    exit 0;
}

usage();
