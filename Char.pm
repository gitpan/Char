package Char;
######################################################################
#
# Char - Character Oriented Perl by Magic Comment
#
#                  http://search.cpan.org/dist/Char/
#
# Copyright (c) 2010 INABA Hitoshi <ina@cpan.org>
#
######################################################################

use 5.00503;

BEGIN { eval q{ use vars qw($VERSION) } }
$VERSION = sprintf '%d.%02d', q$Revision: 0.03 $ =~ m/(\d+)/oxmsg;
BEGIN { eval { require strict; 'strict'->import; } }

unless (eval q{ use Fcntl qw(:flock); 1 }) {
    eval q{
        sub LOCK_SH {1}
        sub LOCK_EX {2}
        sub LOCK_UN {8}
        sub LOCK_NB {4}
    };
}

local $^W = 1;
$| = 1;

sub import() {}
sub unimport() {}

my $__FILE__ = __FILE__;
my(undef,$filename) = caller 0;

# when magic comment exists
if (my $encoding = encoding($filename)) {

    # get filter software path
    my $filter = abspath($encoding);
    unless ($filter) {
        die "$__FILE__: filter software '$encoding.pm' not found in \@INC(@INC)\n";
    }

    # when escaped script not exists or older
    my $e_mtime = (stat("$filename.e"))[9];
    my $mtime   = (stat($filename))[9];
    if ((not -e "$filename.e") or ($e_mtime < $mtime)) {
        open(FILE1, "+>>$filename")   or die "$__FILE__: Can't read-write open file: $filename\n";
        if ($^O eq 'MacOS') {
            eval q{
                require Mac::Files;
                Mac::Files::FSpSetFLock($filename);
            };
        }
        else {
            eval q{ flock(FILE1, LOCK_EX) };
        }

        # rewrite 'Char::' to any encoding
        open(FILE2, ">$filename.tmp") or die "$__FILE__: Can't write open file: $filename.tmp\n";
        while (<FILE1>) {
            s/^\s*use\s+Char\s*;\s*$//g;
            s/(?!<::)\b(ord|reverse)\b/'Char::'.$1/ge;
            s/\bChar::(ord|reverse|length|substr|index|rindex)\b/$encoding.'::'.$1/ge;
            print FILE2 $_;
        }
        close(FILE2) or die "$__FILE__: Can't close file: $filename.tmp\n";

        # escape perl script
        my @system  = ();
        my $escaped = '';
        if ($^O =~ m/\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
            @system    = map {m/[ ]/oxms ? qq{"$_"} : $_}  $^X, $filter, "$filename.tmp";
            ($escaped) = map {m/[ ]/oxms ? qq{"$_"} : $_}  "$filename.e";
        }
        elsif ($^O eq 'MacOS') {
            @system    = map { _escapeshellcmd_MacOS($_) } $^X, $filter, "$filename.tmp";
            ($escaped) = map { _escapeshellcmd_MacOS($_) } "$filename.e";
        }
        else {
            @system    = map { _escapeshellcmd($_) }       $^X, $filter, "$filename.tmp";
            ($escaped) = map { _escapeshellcmd($_) }       "$filename.e";
        }
        if (system(join ' ', @system, '>', $escaped) == 0) {
            unlink "$filename.tmp";
        }

        # inherit file mode
        my $mode = (stat($filename))[2] & 0777;
        chmod $mode, "$filename.e";

        # close file and unlock
        if ($^O eq 'MacOS') {
            eval q{
                require Mac::Files;
                Mac::Files::FSpRstFLock($filename);
            };
        }
        close(FILE1) or die "$__FILE__: Can't close file: $filename\n";
    }

    # execute escaped script
    my $system;
    local @ENV{qw(IFS CDPATH ENV BASH_ENV)};
    if ($^O =~ m/\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
        open(FILE1, $filename) or die "$__FILE__: Can't read open file: $filename\n";
        eval q{ flock(FILE1, LOCK_SH) };
        $system = system map {m/[ ]/oxms ? qq{"$_"} : $_} $^X, "$filename.e", @ARGV;
        close(FILE1) or die "$__FILE__: Can't close file: $filename\n";
    }
    elsif ($^O eq 'MacOS') {
        eval q{
            require Mac::Files;
            Mac::Files::FSpSetFLock($filename);
        };
        $system = system map { _escapeshellcmd_MacOS($_) } $^X, "$filename.e", @ARGV;
        eval q{
            require Mac::Files;
            Mac::Files::FSpRstFLock($filename);
        };
    }
    else {
        open(FILE1, $filename) or die "$__FILE__: Can't read open file: $filename\n";
        eval q{ flock(FILE1, LOCK_SH) };
        $system = system map { _escapeshellcmd($_) } $^X, "$filename.e", @ARGV;
        close(FILE1) or die "$__FILE__: Can't close file: $filename\n";
    }

    exit $system;
}

# when no magic comment
else {
    warn "$__FILE__: no magic comment.\n";
}

# escape shell command line on Mac OS
sub _escapeshellcmd_MacOS {
    my($word) = @_;
    $word =~ s/(["`{\xB6])/\xB6$1/g;
    return qq{"$word"};
}

# escape shell command line on UNIX-like system
sub _escapeshellcmd {
    my($word) = @_;
    $word =~ s/([\t\n\r\x20!"#\$%&'()*+;<=>?\[\\\]^`{|}~\x7F\xFF])/\\$1/g;
    return $word;
}

# get encoding from magic comment
sub encoding {
    my($filename) = @_;
    my $encoding = '';

    open(FILE, $filename) or die "$__FILE__: Can't write open file: $filename\n";
    while (<FILE>) {
        chomp;
        if (($encoding) = m/coding[:=]\s*(.+)/oxms) {
            last;
        }
        if ($. > 100) {
            last;
        }
    }
    close(FILE) or die "$__FILE__: Can't close file: $filename\n";

    return '' unless $encoding;

    # resolve alias of encoding
    $encoding = lc $encoding;
    $encoding =~ tr/a-z0-9//cd;
    return { qw(

    shiftjis            Sjis
    shiftjisx0213       Sjis
    shiftjis2004        Sjis
    sjis                Sjis
    sjisx0213           Sjis
    sjis2004            Sjis
    cp932               Sjis
    windows31j          Sjis
    cswindows31j        Sjis
    sjiswin             Sjis
    macjapanese         Sjis
    macjapan            Sjis
    xsjis               Sjis
    mskanji             Sjis
    csshiftjis          Sjis
    windowscodepage932  Sjis
    ibmcp943            Sjis
    ms932               Sjis

    eucjp               EUCJP
    euc                 EUCJP
    ujis                EUCJP
    eucjpms             EUCJP
    eucjpwin            EUCJP
    cp51932             EUCJP

    utf8                UTF2
    utf2                UTF2
    utffss              UTF2
    utf8mac             UTF2

    cesu8               OldUTF8
    modifiedutf8        OldUTF8

    hp15                HP15
    informixv6als       INFORMIXV6ALS

    gb18030             GB18030
    gbk                 GBK
    gb2312              GBK
    cp936               GBK
    euccn               GBK

    uhc                 UHC
    ksx1001             UHC
    ksc5601             UHC
    ksc56011987         UHC
    ks                  UHC
    cp949               UHC
    windows949          UHC

    big5plus            Big5Plus
    big5                Big5Plus
    big5et              Big5Plus
    big5eten            Big5Plus
    tcabig5             Big5Plus
    cp950               Big5Plus

    big5hk              Big5HKSCS
    big5hkscs           Big5HKSCS
    hkbig5              Big5HKSCS
    hkscsbig5           Big5HKSCS

    latin1              Latin1
    isoiec88591         Latin1
    iso88591            Latin1
    iec88591            Latin1

    )}->{$encoding} || $encoding;
}

# get absolute path to filter software
sub abspath {
    my($encoding) = @_;
    for my $path (@INC) {
        if ($^O eq 'MacOS') {
            if (-e "$path$encoding.pm") {
                return "$path$encoding.pm";
            }
        }
        else {
            if (-e "$path/$encoding.pm") {
                return "$path/$encoding.pm";
            }
        }
    }
    return '';
}

1;

__END__

=pod

=head1 NAME

Char - Character Oriented Perl by Magic Comment

=head1 SYNOPSIS

  # encoding: sjis
  use Char;

  functions:
    Char::ord(...);
    Char::reverse(...);
    Char::length(...);
    Char::substr(...);
    Char::index(...);
    Char::rindex(...);

  # "no Char;" not supported

=head1 SOFTWARE COMPOSITION

   Char.pm --- Character Oriented Perl by Magic Comment

=head1 OTHER SOFTWARE

To using this software, you must get filter software of 'Yet Another JPerl family'.
See also following 'SEE ALSO'.

INSTALLATION BY MAKE (for UNIX-like system)

To install this software by make, type the following:

   perl Makefile.PL
   make
   make test
   make install

INSTALLATION WITHOUT MAKE (for DOS-like system)

To install this software without make, type the following:

   perl pMakefile.PL    --- pMakefile.PL makes "pmake.bat" only, and ...
   pmake.bat
   pmake.bat test
   pmake.bat install    --- install to current using Perl

   pmake.bat dist       --- make distribution package
   pmake.bat ptar.bat   --- make perl script "ptar.bat"

=head1 DEPENDENCIES

This software requires perl5.00503 or later.

=head1 MAGIC COMMENT

You should show the encoding method of your script by either of the following
descriptions. (.+) is an encoding method. It is necessary to describe this
description from the 1st line to the 100th line of the script.

  m/coding[:=]\s*(.+)/oxms

  Example:

  # -*- coding: Shift_JIS -*-
  print "Emacs like\n";

  # vim:fileencoding=Latin-1
  print "Vim like 1";

  # vim:set fileencoding=GB18030 :
  print "Vim like 2";

  #coding:Modified UTF-8
  print "simple";

=head1 ENCODING METHOD

The encoding method is evaluated, after it is regularized.

  regularize:
    1. The upper case characters are converted into lower case.
    2. Left only alphabet and number, others are removed.

The filter software is selected by using the following tables. The script does
die if there is no filter software.

  -----------------------------------
  encoding method     filter software
  -----------------------------------
  shiftjis            Sjis
  shiftjisx0213       Sjis
  shiftjis2004        Sjis
  sjis                Sjis
  sjisx0213           Sjis
  sjis2004            Sjis
  cp932               Sjis
  windows31j          Sjis
  cswindows31j        Sjis
  sjiswin             Sjis
  macjapanese         Sjis
  macjapan            Sjis
  xsjis               Sjis
  mskanji             Sjis
  csshiftjis          Sjis
  windowscodepage932  Sjis
  ibmcp943            Sjis
  ms932               Sjis
  eucjp               EUCJP
  euc                 EUCJP
  ujis                EUCJP
  eucjpms             EUCJP
  eucjpwin            EUCJP
  cp51932             EUCJP
  utf8                UTF2
  utf2                UTF2
  utffss              UTF2
  utf8mac             UTF2
  cesu8               OldUTF8
  modifiedutf8        OldUTF8
  hp15                HP15
  informixv6als       INFORMIXV6ALS
  gb18030             GB18030
  gbk                 GBK
  gb2312              GBK
  cp936               GBK
  euccn               GBK
  uhc                 UHC
  ksx1001             UHC
  ksc5601             UHC
  ksc56011987         UHC
  ks                  UHC
  cp949               UHC
  windows949          UHC
  big5plus            Big5Plus
  big5                Big5Plus
  big5et              Big5Plus
  big5eten            Big5Plus
  tcabig5             Big5Plus
  cp950               Big5Plus
  big5hk              Big5HKSCS
  big5hkscs           Big5HKSCS
  hkbig5              Big5HKSCS
  hkscsbig5           Big5HKSCS
  latin1              Latin1
  isoiec88591         Latin1
  iso88591            Latin1
  iec88591            Latin1
  -----------------------------------

=head1 CHARACTER ORIENTED FUNCTIONS

=item Order of Character

  $ord = ord($string);

  or

  $ord = Char::ord($string);

  In default, ord functions as character oriented Char::ord, and if you want to have
  byte oriented ord, you must write CORE::ord.

  This function returns the numeric value (ASCII or Multibyte Character) of the
  first character of $string. The return value is always unsigned.

=item Reverse List or String

  @reverse = reverse(@list);
  $reverse = reverse(@list);

  or

  @reverse = Char::reverse(@list);
  $reverse = Char::reverse(@list);

  In default, reverse functions as character oriented Char::reverse, and if you want
  to have byte oriented reverse, you must write CORE::reverse.

  In list context, this function returns a list value consisting of the elements of
  @list in the opposite order. The function can be used to create descending
  sequences:

  for (Char::reverse(1 .. 10)) { ... }

  Because of the way hashes flatten into lists when passed as a @list, reverse can
  also be used to invert a hash, presuming the values are unique:

  %barfoo = Char::reverse(%foobar);

  In scalar context, the function concatenates all the elements of LIST and then
  returns the reverse of that resulting string, character by character.

=item Length by Character

  $length = Char::length($string);
  $length = Char::length();

  This function returns the length in characters of the scalar value $string. If
  $string is omitted, it returns the Char::length of $_.

  Do not try to use length to find the size of an array or hash. Use scalar @array
  for the size of an array, and scalar keys %hash for the number of key/value pairs
  in a hash. (The scalar is typically omitted when redundant.)

  To find the length of a string in bytes rather than characters, say:

  $blen = length($string);

  or

  $blen = CORE::length($string);

=item Substr by Character

  $substr = Char::substr($string,$offset,$length,$replacement);
  $substr = Char::substr($string,$offset,$length);
  $substr = Char::substr($string,$offset);

  This function extracts a substring out of the string given by $string and returns
  it. The substring is extracted starting at $offset characters from the front of
  the string.
  If $offset is negative, the substring starts that far from the end of the string
  instead. If $length is omitted, everything to the end of the string is returned.
  If $length is negative, the length is calculated to leave that many characters off
  the end of the string. Otherwise, $length indicates the length of the substring to
  extract, which is sort of what you'd expect.

  An alternative to using Char::substr as an lvalue is to specify the $replacement
  string as the fourth argument. This allows you to replace parts of the $string and
  return what was there before in one operation, just as you can with splice. The next
  example also replaces the last character of $var with "Curly" and puts that replaced
  character into $oldstr: 

  $oldstr = Char::substr($var, -1, 1, "Curly");

  If you assign something shorter than the length of your substring, the string will
  shrink, and if you assign something longer than the length, the string will grow to
  accommodate it. To keep the string the same length, you may need to pad or chop your
  value using sprintf or the x operator. If you attempt to assign to an unallocated
  area past the end of the string, Char::substr raises an exception.

  To prepend the string "Larry" to the current value of $_, use:

  Char::substr($var, 0, 0, "Larry");

  To instead replace the first character of $_ with "Moe", use:

  Char::substr($var, 0, 1, "Moe");

  And finally, to replace the last character of $var with "Curly", use:

  Char::substr($var, -1, 1, "Curly");

=item Index by Character

  $index = Char::index($string,$substring,$offset);
  $index = Char::index($string,$substring);

  This function searches for one string within another. It returns the position of
  the first occurrence of $substring in $string. The $offset, if specified, says how
  many characters from the start to skip before beginning to look. Positions are
  based at 0. If the substring is not found, the function returns one less than the
  base, ordinarily -1. To work your way through a string, you might say:

  $pos = -1;
  while (($pos = Char::index($string, $lookfor, $pos)) > -1) {
      print "Found at $pos\n";
      $pos++;
  }

=item Rindex by Character

  $rindex = Char::rindex($string,$substring,$position);
  $rindex = Char::rindex($string,$substring);

  This function works just like Char::index except that it returns the position of
  the last occurrence of $substring in $string (a reverse index). The function
  returns -1 if not $substring is found. $position, if specified, is the rightmost
  position that may be returned. To work your way through a string backward, say:

  $pos = Char::length($string);
  while (($pos = Char::rindex($string, $lookfor, $pos)) >= 0) {
      print "Found at $pos\n";
      $pos--;
  }

=back

=head1 AUTHOR

INABA Hitoshi E<lt>ina@cpan.orgE<gt>

This project was originated by INABA Hitoshi.

=head1 LICENSE AND COPYRIGHT

This software is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 SEE ALSO

 Yet Another JPerl family
 http://search.cpan.org/dist/Big5HKSCS/
 http://search.cpan.org/dist/Big5Plus/
 http://search.cpan.org/dist/EUCJP/
 http://search.cpan.org/dist/GB18030/
 http://search.cpan.org/dist/GBK/
 http://search.cpan.org/dist/HP15/
 http://search.cpan.org/dist/INFORMIXV6ALS/
 http://search.cpan.org/dist/Latin1/
 http://search.cpan.org/dist/OldUTF8/
 http://search.cpan.org/dist/Sjis/
 http://search.cpan.org/dist/UHC/
 http://search.cpan.org/dist/UTF2/

=head1 ACKNOWLEDGEMENTS

This software was made referring to software and the document that the
following hackers or persons had made. Especially, Yukihiro Matsumoto taught
to us,

CSI is not impossible.

I am thankful to all persons.

 Larry Wall, Perl
 http://www.perl.org/

 Yukihiro "Matz" Matsumoto, YAPC::Asia2006 Ruby on Perl(s)
 http://www.rubyist.net/~matz/slides/yapc2006/

 About Ruby M17N in Rubyist Magazine
 http://jp.rubyist.net/magazine/?0025-Ruby19_m17n#l13

=cut

