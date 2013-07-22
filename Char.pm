package Char;
######################################################################
#
# Char - Character Oriented Perl by Magic Comment
#
# Copyright (c) 2010, 2011, 2013 INABA Hitoshi <ina@cpan.org>
#
######################################################################

use 5.00503;

BEGIN { eval q{ use vars qw($VERSION) } }
$VERSION = sprintf '%d.%02d', q$Revision: 0.09 $ =~ m/(\d+)/oxmsg;

sub LOCK_SH() {1}
sub LOCK_EX() {2}
sub LOCK_UN() {8}
sub LOCK_NB() {4}

local $^W = 1;
$| = 1;

sub unimport {}

BEGIN { eval q{ use vars qw($OSNAME $LANG) } }
($OSNAME, $LANG) = ($^O,       $ENV{'LANG'});
($OSNAME, $LANG) = ('MSWin32', undef)         if 0;
($OSNAME, $LANG) = ('darwin',  'ja_JP.UTF-8') if 0;
($OSNAME, $LANG) = ('MacOS',   undef)         if 0;
($OSNAME, $LANG) = ('solaris', 'ja')          if 0;
($OSNAME, $LANG) = ('hpux',    'SJIS')        if 0;
($OSNAME, $LANG) = ('aix',     'Ja_JP')       if 0;

#
# poor Symbol.pm - substitute of real Symbol.pm
#
BEGIN {
    my $genpkg = "Symbol::";
    my $genseq = 0;

    sub gensym () {
        my $name = "GEN" . $genseq++;

        # here, no strict qw(refs); if strict.pm exists

        my $ref = \*{$genpkg . $name};
        delete $$genpkg{$name};
        return $ref;
    }
}

#
# source code filter
#
sub import {
    my(undef,$filename) = caller 0;

    # when escaped script not exists or older
    my $e_mtime = (stat("$filename.e"))[9];
    my $mtime   = (stat($filename))[9];
    if ((not -e "$filename.e") or ($e_mtime < $mtime)) {
        my $fh1 = gensym();
        _open_r($fh1, $filename) or die "@{[__FILE__]}: Can't read open file: $filename\n";
        if ($OSNAME eq 'MacOS') {
            eval q{
                require Mac::Files;
                Mac::Files::FSpSetFLock($filename);
            };
        }
        else {
            eval q{ flock($fh1, LOCK_EX) };
        }

        # when magic comment exists
        my $encoding = '';
        my $filter = '';
        if ($encoding = (from_magic_comment($filename) || from_chcp_lang())) {
            $filter = abspath($encoding);
            if ($filter eq '') {
                die "@{[__FILE__]}: filter software '$encoding.pm' not found in \@INC(@INC)\n";
            }
        }
        else {
            warn "@{[__FILE__]}: don't know which encoding.\n";
        }

        # rewrite 'Char::' to any encoding
        my $fh2 = gensym();
        _open_w($fh2, "$filename.tmp") or die "@{[__FILE__]}: Can't write open file: $filename.tmp\n";
        while (<$fh1>) {
            s/\A \s* use \s+ Char \s* [^;]* ;\s* \z//oxmsg;
            s/\bChar::(ord|reverse|getc|length|substr|index|rindex)\b/$encoding.'::'.$1/ge;
            print {$fh2} $_;
        }
        close($fh2) or die "@{[__FILE__]}: Can't close file: $filename.tmp\n";

        # escape perl script
        my @system  = ();
        my $escaped = '';
        if ($OSNAME =~ m/\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
            @system    = map { _escapeshellcmd_MSWin32($_) } $^X, $filter, "$filename.tmp";
            ($escaped) = map { _escapeshellcmd_MSWin32($_) } "$filename.e";
        }
        elsif ($OSNAME eq 'MacOS') {
            @system    = map { _escapeshellcmd_MacOS($_) }   $^X, $filter, "$filename.tmp";
            ($escaped) = map { _escapeshellcmd_MacOS($_) }   "$filename.e";
        }
        else {
            @system    = map { _escapeshellcmd($_) }         $^X, $filter, "$filename.tmp";
            ($escaped) = map { _escapeshellcmd($_) }         "$filename.e";
        }
        if (_systemx(join ' ', @system, '>', $escaped) == 0) {
            unlink "$filename.tmp";
        }

        # inherit file mode
        my $mode = (stat($filename))[2] & 0777;
        chmod $mode, "$filename.e";

        # close file and unlock
        if ($OSNAME eq 'MacOS') {
            eval q{
                require Mac::Files;
                Mac::Files::FSpRstFLock($filename);
            };
        }
        close($fh1) or die "@{[__FILE__]}: Can't close file: $filename\n";
    }

    # execute escaped script
    my $system;
    if ($OSNAME =~ m/\A (?: MSWin32 | NetWare | symbian | dos ) \z/oxms) {
        my $fh = gensym();
        _open_r($fh, $filename) or die "@{[__FILE__]}: Can't read open file: $filename\n";
        eval q{ flock($fh, LOCK_SH) };
        $system = _systemx(map { _escapeshellcmd_MSWin32($_) } $^X, "$filename.e", @ARGV);
        close($fh) or die "@{[__FILE__]}: Can't close file: $filename\n";
    }
    elsif ($OSNAME eq 'MacOS') {
        eval q{
            require Mac::Files;
            Mac::Files::FSpSetFLock($filename);
        };
        $system = _systemx(map { _escapeshellcmd_MacOS($_) } $^X, "$filename.e", @ARGV);
        eval q{
            require Mac::Files;
            Mac::Files::FSpRstFLock($filename);
        };
    }
    else {
        my $fh = gensym();
        _open_r($fh, $filename) or die "@{[__FILE__]}: Can't read open file: $filename\n";
        eval q{ flock($fh, LOCK_SH) };
        $system = _systemx(map { _escapeshellcmd($_) } $^X, "$filename.e", @ARGV);
        close($fh) or die "@{[__FILE__]}: Can't close file: $filename\n";
    }

    exit $system;
}

#
# open file in read mode
#
sub _open_r {
    my(undef,$file) = @_;
    $file =~ s#\A (\s) #./$1#oxms;
    return eval(q{open($_[0],'<',$_[1])}) ||
                  open($_[0],"< $file\0");
}

#
# open file in write mode
#
sub _open_w {
    my(undef,$file) = @_;
    $file =~ s#\A (\s) #./$1#oxms;
    return eval(q{open($_[0],'>',$_[1])}) ||
                  open($_[0],"> $file\0");
}

#
# safe system
#
sub _systemx {
    $| = 1;
    local @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Make %ENV safer
#   return CORE::system { $_[0] } @_;
    return CORE::system           @_;
}

#
# escape shell command line on DOS-like system
#
sub _escapeshellcmd_MSWin32 {
    my($word) = @_;
    if ($word =~ / [ ] /oxms) {

        # both DOS-like and UNIX-like shell quote
        return qq{"$word"};
    }
    else {
        return $word;
    }
}

#
# escape shell command line on Mac OS
#
sub _escapeshellcmd_MacOS {
    my($word) = @_;
    return $word;
}

#
# escape shell command line on UNIX-like system
#
sub _escapeshellcmd {
    my($word) = @_;
    return $word;
}

#
# get encoding from magic comment
#
sub from_magic_comment {
    my($filename) = @_;
    my $encoding = '';

    my $fh = gensym();
    _open_r($fh, $filename) or die "@{[__FILE__]}: Can't read open file: $filename\n";
    while (<$fh>) {
        chomp;
        if (($encoding) = m/coding[:=]\s*(.+)/oxms) {
            last;
        }
    }
    close($fh) or die "@{[__FILE__]}: Can't close file: $filename\n";

    return '' unless $encoding;

    # resolve alias of encoding
    $encoding = lc $encoding;
    $encoding =~ tr/a-z0-9//cd;
    return { qw(

    ascii               USASCII
    usascii             USASCII

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

    jisc6220            JIS8
    jisx0201            JIS8
    jis8                JIS8
    ank                 JIS8

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

    kps9566             KPS9566
    kps95662003         KPS9566
    kps95662000         KPS9566
    kps95661997         KPS9566
    kps956697           KPS9566
    euckp               KPS9566

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

    latin2              Latin2
    isoiec88592         Latin2
    iso88592            Latin2
    iec88592            Latin2

    latin3              Latin3
    isoiec88593         Latin3
    iso88593            Latin3
    iec88593            Latin3

    latin4              Latin4
    isoiec88594         Latin4
    iso88594            Latin4
    iec88594            Latin4

    cyrillic            Cyrillic
    isoiec88595         Cyrillic
    iso88595            Cyrillic
    iec88595            Cyrillic

    koi8r               KOI8R
    koi8u               KOI8U

    arabic              Arabic
    isoiec88596         Arabic
    iso88596            Arabic
    iec88596            Arabic

    greek               Greek
    isoiec88597         Greek
    iso88597            Greek
    iec88597            Greek

    hebrew              Hebrew
    isoiec88598         Hebrew
    iso88598            Hebrew
    iec88598            Hebrew

    latin5              Latin5
    isoiec88599         Latin5
    iso88599            Latin5
    iec88599            Latin5

    latin6              Latin6
    isoiec885910        Latin6
    iso885910           Latin6
    iec885910           Latin6

    tis620              TIS620
    tis6202533          TIS620
    isoiec885911        TIS620
    iso885911           TIS620
    iec885911           TIS620

    latin7              Latin7
    isoiec885913        Latin7
    iso885913           Latin7
    iec885913           Latin7

    latin8              Latin8
    isoiec885914        Latin8
    iso885914           Latin8
    iec885914           Latin8

    latin9              Latin9
    isoiec885915        Latin9
    iso885915           Latin9
    iec885915           Latin9

    latin10             Latin10
    isoiec885916        Latin10
    iso885916           Latin10
    iec885916           Latin10

    windows1252         Windows1252

    windows1258         Windows1258

    )}->{$encoding} || $encoding;
}

#
# encoding from chcp or LANG environment variable
#
sub from_chcp_lang {
    my $encoding = '';

    # Microsoft Windows
    if ($OSNAME eq 'MSWin32') {
        $encoding = {

        # Code Page Identifiers (Windows)
        # Identifier .NET Name Additional information

          '037' => '', # IBM037 IBM EBCDIC US-Canada
          '437' => '', # IBM437 OEM United States
          '500' => '', # IBM500 IBM EBCDIC International
          '708' => 'Arabic', # ASMO-708 Arabic (ASMO 708)
          '709' => '', #  Arabic (ASMO-449+, BCON V4)
          '710' => '', #  Arabic - Transparent Arabic
          '720' => '', # DOS-720 Arabic (Transparent ASMO); Arabic (DOS)
          '737' => '', # ibm737 OEM Greek (formerly 437G); Greek (DOS)
          '775' => '', # ibm775 OEM Baltic; Baltic (DOS)
          '850' => '', # ibm850 OEM Multilingual Latin 1; Western European (DOS)
          '852' => '', # ibm852 OEM Latin 2; Central European (DOS)
          '855' => '', # IBM855 OEM Cyrillic (primarily Russian)
          '857' => '', # ibm857 OEM Turkish; Turkish (DOS)
          '858' => '', # IBM00858 OEM Multilingual Latin 1 + Euro symbol
          '860' => '', # IBM860 OEM Portuguese; Portuguese (DOS)
          '861' => '', # ibm861 OEM Icelandic; Icelandic (DOS)
          '862' => '', # DOS-862 OEM Hebrew; Hebrew (DOS)
          '863' => '', # IBM863 OEM French Canadian; French Canadian (DOS)
          '864' => '', # IBM864 OEM Arabic; Arabic (864)
          '865' => '', # IBM865 OEM Nordic; Nordic (DOS)
          '866' => '', # cp866 OEM Russian; Cyrillic (DOS)
          '869' => '', # ibm869 OEM Modern Greek; Greek, Modern (DOS)
          '870' => '', # IBM870 IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
          '874' => 'TIS620', # windows-874 ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)
          '875' => '', # cp875 IBM EBCDIC Greek Modern
          '932' => 'Sjis', # shift_jis ANSI/OEM Japanese; Japanese (Shift-JIS)
          '936' => 'GBK', # gb2312 ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
          '949' => 'UHC', # ks_c_5601-1987 ANSI/OEM Korean (Unified Hangul Code)
          '950' => 'Big5Plus', # big5 ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
         '1026' => '', # IBM1026 IBM EBCDIC Turkish (Latin 5)
         '1047' => '', # IBM01047 IBM EBCDIC Latin 1/Open System
         '1140' => '', # IBM01140 IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
         '1141' => '', # IBM01141 IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
         '1142' => '', # IBM01142 IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
         '1143' => '', # IBM01143 IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
         '1144' => '', # IBM01144 IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
         '1145' => '', # IBM01145 IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
         '1146' => '', # IBM01146 IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
         '1147' => '', # IBM01147 IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
         '1148' => '', # IBM01148 IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
         '1149' => '', # IBM01149 IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
         '1200' => '', # utf-16 Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
         '1201' => '', # unicodeFFFE Unicode UTF-16, big endian byte order; available only to managed applications
         '1250' => '', # windows-1250 ANSI Central European; Central European (Windows)
         '1251' => '', # windows-1251 ANSI Cyrillic; Cyrillic (Windows)
         '1252' => 'Windows1252', # windows-1252 ANSI Latin 1; Western European (Windows)
         '1253' => '', # windows-1253 ANSI Greek; Greek (Windows)
         '1254' => '', # windows-1254 ANSI Turkish; Turkish (Windows)
         '1255' => 'Hebrew', # windows-1255 ANSI Hebrew; Hebrew (Windows)
         '1256' => '', # windows-1256 ANSI Arabic; Arabic (Windows)
         '1257' => '', # windows-1257 ANSI Baltic; Baltic (Windows)
         '1258' => 'Windows1258', # windows-1258 ANSI/OEM Vietnamese; Vietnamese (Windows)
         '1361' => '', # Johab Korean (Johab)
        '10000' => '', # macintosh MAC Roman; Western European (Mac)
        '10001' => '', # x-mac-japanese Japanese (Mac)
        '10002' => '', # x-mac-chinesetrad MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
        '10003' => '', # x-mac-korean Korean (Mac)
        '10004' => '', # x-mac-arabic Arabic (Mac)
        '10005' => '', # x-mac-hebrew Hebrew (Mac)
        '10006' => '', # x-mac-greek Greek (Mac)
        '10007' => '', # x-mac-cyrillic Cyrillic (Mac)
        '10008' => '', # x-mac-chinesesimp MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
        '10010' => '', # x-mac-romanian Romanian (Mac)
        '10017' => '', # x-mac-ukrainian Ukrainian (Mac)
        '10021' => '', # x-mac-thai Thai (Mac)
        '10029' => '', # x-mac-ce MAC Latin 2; Central European (Mac)
        '10079' => '', # x-mac-icelandic Icelandic (Mac)
        '10081' => '', # x-mac-turkish Turkish (Mac)
        '10082' => '', # x-mac-croatian Croatian (Mac)
        '12000' => '', # utf-32 Unicode UTF-32, little endian byte order; available only to managed applications
        '12001' => '', # utf-32BE Unicode UTF-32, big endian byte order; available only to managed applications
        '20000' => '', # x-Chinese_CNS CNS Taiwan; Chinese Traditional (CNS)
        '20001' => '', # x-cp20001 TCA Taiwan
        '20002' => '', # x_Chinese-Eten Eten Taiwan; Chinese Traditional (Eten)
        '20003' => '', # x-cp20003 IBM5550 Taiwan
        '20004' => '', # x-cp20004 TeleText Taiwan
        '20005' => '', # x-cp20005 Wang Taiwan
        '20105' => '', # x-IA5 IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
        '20106' => '', # x-IA5-German IA5 German (7-bit)
        '20107' => '', # x-IA5-Swedish IA5 Swedish (7-bit)
        '20108' => '', # x-IA5-Norwegian IA5 Norwegian (7-bit)
        '20127' => 'USASCII', # us-ascii US-ASCII (7-bit)
        '20261' => '', # x-cp20261 T.61
        '20269' => '', # x-cp20269 ISO 6937 Non-Spacing Accent
        '20273' => '', # IBM273 IBM EBCDIC Germany
        '20277' => '', # IBM277 IBM EBCDIC Denmark-Norway
        '20278' => '', # IBM278 IBM EBCDIC Finland-Sweden
        '20280' => '', # IBM280 IBM EBCDIC Italy
        '20284' => '', # IBM284 IBM EBCDIC Latin America-Spain
        '20285' => '', # IBM285 IBM EBCDIC United Kingdom
        '20290' => '', # IBM290 IBM EBCDIC Japanese Katakana Extended
        '20297' => '', # IBM297 IBM EBCDIC France
        '20420' => '', # IBM420 IBM EBCDIC Arabic
        '20423' => '', # IBM423 IBM EBCDIC Greek
        '20424' => '', # IBM424 IBM EBCDIC Hebrew
        '20833' => '', # x-EBCDIC-KoreanExtended IBM EBCDIC Korean Extended
        '20838' => '', # IBM-Thai IBM EBCDIC Thai
        '20866' => 'KOI8R', # koi8-r Russian (KOI8-R); Cyrillic (KOI8-R)
        '20871' => '', # IBM871 IBM EBCDIC Icelandic
        '20880' => '', # IBM880 IBM EBCDIC Cyrillic Russian
        '20905' => '', # IBM905 IBM EBCDIC Turkish
        '20924' => '', # IBM00924 IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
        '20932' => 'EUCJP', # EUC-JP Japanese (JIS 0208-1990 and 0121-1990)
        '20936' => '', # x-cp20936 Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
        '20949' => '', # x-cp20949 Korean Wansung
        '21025' => '', # cp1025 IBM EBCDIC Cyrillic Serbian-Bulgarian
        '21027' => '', #  (deprecated)
        '21866' => 'KOI8U', # koi8-u Ukrainian (KOI8-U); Cyrillic (KOI8-U)
        '28591' => 'Latin1', # iso-8859-1 ISO 8859-1 Latin 1; Western European (ISO)
        '28592' => 'Latin2', # iso-8859-2 ISO 8859-2 Central European; Central European (ISO)
        '28593' => 'Latin3', # iso-8859-3 ISO 8859-3 Latin 3
        '28594' => 'Latin4', # iso-8859-4 ISO 8859-4 Baltic
        '28595' => 'Cyrillic', # iso-8859-5 ISO 8859-5 Cyrillic
        '28596' => 'Arabic', # iso-8859-6 ISO 8859-6 Arabic
        '28597' => 'Greek', # iso-8859-7 ISO 8859-7 Greek
        '28598' => 'Hebrew', # iso-8859-8 ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
        '28599' => 'Latin5', # iso-8859-9 ISO 8859-9 Turkish
        '28603' => 'Latin7', # iso-8859-13 ISO 8859-13 Estonian
        '28605' => 'Latin9', # iso-8859-15 ISO 8859-15 Latin 9
        '29001' => '', # x-Europa Europa 3
        '38598' => '', # iso-8859-8-i ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
        '50220' => '', # iso-2022-jp ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
        '50221' => '', # csISO2022JP ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
        '50222' => '', # iso-2022-jp ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)
        '50225' => '', # iso-2022-kr ISO 2022 Korean
        '50227' => '', # x-cp50227 ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
        '50229' => '', #  ISO 2022 Traditional Chinese
        '50930' => '', #  EBCDIC Japanese (Katakana) Extended
        '50931' => '', #  EBCDIC US-Canada and Japanese
        '50933' => '', #  EBCDIC Korean Extended and Korean
        '50935' => '', #  EBCDIC Simplified Chinese Extended and Simplified Chinese
        '50936' => '', #  EBCDIC Simplified Chinese
        '50937' => '', #  EBCDIC US-Canada and Traditional Chinese
        '50939' => '', #  EBCDIC Japanese (Latin) Extended and Japanese
        '51932' => 'EUCJP', # euc-jp EUC Japanese
        '51936' => '', # EUC-CN EUC Simplified Chinese; Chinese Simplified (EUC)
        '51949' => '', # euc-kr EUC Korean
        '51950' => '', #  EUC Traditional Chinese
        '52936' => '', # hz-gb-2312 HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
        '54936' => 'GB18030', # GB18030 Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
        '57002' => '', # x-iscii-de ISCII Devanagari
        '57003' => '', # x-iscii-be ISCII Bengali
        '57004' => '', # x-iscii-ta ISCII Tamil
        '57005' => '', # x-iscii-te ISCII Telugu
        '57006' => '', # x-iscii-as ISCII Assamese
        '57007' => '', # x-iscii-or ISCII Oriya
        '57008' => '', # x-iscii-ka ISCII Kannada
        '57009' => '', # x-iscii-ma ISCII Malayalam
        '57010' => '', # x-iscii-gu ISCII Gujarati
        '57011' => '', # x-iscii-pa ISCII Punjabi
        '65000' => '', # utf-7 Unicode (UTF-7)
        '65001' => 'UTF2', # utf-8 Unicode (UTF-8)

        }->{(qx{chcp} =~ m/([0-9]{3,5}) \Z/oxms)[0]};
    }

    # C or POSIX
    elsif (not defined($LANG) or ($LANG eq '')) {
        $encoding = 'USASCII';
    }
    elsif ($LANG =~ m/\A (?: C | POSIX ) \z/oxms) {
        $encoding = 'USASCII';
    }

    # Apple Mac OS X
    elsif ($OSNAME eq 'darwin') {
        $encoding = 'UTF2';
    }

    # Apple MacOS
    elsif ($OSNAME eq 'MacOS') {
        die "@{[__FILE__]}: $OSNAME requires magick comment.\n";
    }

    # Oracle Solaris
    elsif ($OSNAME eq 'solaris') {
        my $lang = {

        # Oracle Solaris 10 8/11 Information Library

        qw(

        ar                       ar_EG.ISO8859-6
        bg_BG                    bg_BG.ISO8859-5
        ca                       ca_ES.ISO8859-1
        ca_ES                    ca_ES.ISO8859-1
        cs                       cs_CZ.ISO8859-2
        cs_CZ                    cs_CZ.ISO8859-2
        da                       da_DK.ISO8859-1
        da_DK                    da_DK.ISO8859-1
        da.ISO8859-15            da_DK.ISO8859-15
        de                       de_DE.ISO8859-1
        de_AT                    de_AT.ISO8859-1
        de_CH                    de_CH.ISO8859-1
        de_DE                    de_DE.ISO8859-1
        de.ISO8859-15            de_DE.ISO8859-15
        de.UTF-8                 de_DE.UTF-8
        el                       el_GR.ISO8859-7
        el_GR                    el_GR.ISO8859-7
        el.sun_eu_greek          el_GR.ISO8859-7
        el.UTF-8                 el_CY.UTF-8
        en_AU                    en_AU.ISO8859-1
        en_CA                    en_CA.ISO8859-1
        en_GB                    en_GB.ISO8859-1
        en_IE                    en_IE.ISO8859-1
        en_NZ                    en_NZ.ISO8859-1
        en_US                    en_US.ISO8859-1
        es                       es_ES.ISO8859-1
        es_AR                    es_AR.ISO8859-1
        es_BO                    es_BO.ISO8859-1
        es_CL                    es_CL.ISO8859-1
        es_CO                    es_CO.ISO8859-1
        es_CR                    es_CR.ISO8859-1
        es_EC                    es_EC.ISO8859-1 
        es_ES                    es_ES.ISO8859-1
        es_GT                    es_GT.ISO8859-1
        es.ISO8859-15            es_ES.ISO8859-15
        es_MX                    es_MX.ISO8859-1
        es_NI                    es_NI.ISO8859-1 
        es_PA                    es_PA.ISO8859-1
        es_PE                    es_PE.ISO8859-1
        es_PY                    es_PY.ISO8859-1
        es_SV                    es_SV.ISO8859-1
        es.UTF-8                 es_ES.UTF-8
        es_UY                    es_UY.ISO8859-1
        es_VE                    es_VE.ISO8859-1
        et                       et_EE.ISO8859-15
        et_EE                    et_EE.ISO8859-15
        fi                       fi_FI.ISO8859-1
        fi_FI                    fi_FI.ISO8859-1
        fi.ISO8859-15            fi_FI.ISO8859-15
        fr                       fr_FR.ISO8859-1
        fr_BE                    fr_BE.ISO8859-1
        fr_CA                    fr_CA.ISO8859-1
        fr_CH                    fr_CH.ISO8859-1
        fr_FR                    fr_FR.ISO8859-1
        fr.ISO8859-15            fr_FR.ISO8859-15
        fr.UTF-8                 fr_FR.UTF-8
        he                       he_IL.ISO8859-8
        he_IL                    he_IL.ISO8859-8
        hr_HR                    hr_HR.ISO8859-2
        hu                       hu_HU.ISO8859-2
        hu_HU                    hu_HU.ISO8859-2
        is_IS                    is_IS.ISO8859-1
        it                       it_IT.ISO8859-1
        it.ISO8859-15            it_IT.ISO8859-15
        it_IT                    it_IT.ISO8859-1
        it.UTF-8                 it_IT.UTF-8
        ja                       ja_JP.eucJP
        ko                       ko_KR.EUC
        ko.UTF-8                 ko_KR.UTF-8
        lt                       lt_LT.ISO8859-13
        lt_LT                    lt_LT.ISO8859-13
        lu                       lu_LU.ISO8859-15
        lv                       lv_LV.ISO8859-13
        lv_LV                    lv_LV.ISO8859-13
        mk_MK                    mk_MK.ISO8859-5
        nl                       nl_NL.ISO8859-1
        nl_BE                    nl_BE.ISO8859-1
        nl.ISO8859-15            nl_NL.ISO8859-15
        nl_NL                    nl_NL.ISO8859-1
        no                       nb_NO.ISO8859-1
        no_NO                    nb_NO.ISO8859-1
        no_NO.ISO8859-1@bokmal   nb_NO.ISO8859-1
        no_NO.ISO8859-1@nynorsk  nn_NO.ISO8859-1
        no_NY                    nn_NO.ISO8859-1
        nr                       nr_NR.ISO8859-2
        pl                       pl_PL.ISO8859-2
        pl_PL                    pl_PL.ISO8859-2
        pl.UTF-8                 pl_PL.UTF-8
        pt                       pt_PT.ISO8859-1
        pt_BR                    pt_BR.ISO8859-1
        pt.ISO8859-15            pt_PT.ISO8859-15
        pt_PT                    pt_PT.ISO8859-1
        ro_RO                    ro_RO.ISO8859-2
        ru                       ru_RU.ISO8859-5
        ru.koi8-r                ru_RU.KOI8-R
        ru_RU                    ru_RU.ISO8859-5
        ru.UTF-8                 ru_RU.UTF-8
        sh                       bs_BA.ISO8859-2
        sh_BA                    bs_BA.ISO8859-2
        sh_BA.ISO8859-2@bosnia   bs_BA.ISO8859-2
        sh_BA.UTF-8              bs_BA.UTF-8
        sk_SK                    sk_SK.ISO8859-2
        sl_SI                    sl_SI.ISO8859-2
        sq_AL                    sq_AL.ISO8859-2
        sr_CS                    sr_ME.UTF-8
        sr_CS.UTF-8              sr_ME.UTF-8
        sr_SP                    sr_ME.ISO8859-5
        sr_YU                    sr_ME.ISO8859-5
        sr_YU.ISO8859-5          sr_ME.ISO8859-5
        sv                       sv_SE.ISO8859-1
        sv_SE                    sv_SE.ISO8859-1
        sv.ISO8859-15            sv_SE.ISO8859-15
        sv.UTF-8                 sv_SE.UTF-8
        th                       th_TH.TIS620
        th_TH                    th_TH.TIS620
        th_TH.ISO8859-11         th_TH.TIS620
        tr                       tr_TR.ISO8859-9
        tr_TR                    tr_TR.ISO8859-9
        zh                       zh_CN.EUC
        zh.GBK                   zh_CN.GBK
        zh_TW                    zh_TW.EUC
        zh.UTF-8                 zh_CN.UTF-8
        ca_ES.ISO8859-15@euro    ca_ES.ISO8859-15
        de_AT.ISO8859-15@euro    de_AT.ISO8859-15
        de_DE.ISO8859-15@euro    de_DE.ISO8859-15
        de_DE.UTF-8@euro         de_DE.UTF-8
        el_GR.ISO8859-7@euro     el_GR.ISO8859-7
        en_IE.ISO8859-15@euro    en_IE.ISO8859-15
        es_ES.ISO8859-15@euro    es_ES.ISO8859-15
        es_ES.UTF-8@euro         es_ES.UTF-8
        fi_FI.ISO8859-15@euro    fi_FI.ISO8859-15
        fr_BE.ISO8859-15@euro    fr_BE.ISO8859-15
        fr_BE.UTF-8@euro         fr_BE.UTF-8
        fr_FR.ISO8859-15@euro    fr_FR.ISO8859-15
        fr_FR.UTF-8@euro         fr_FR.UTF-8
        it_IT.ISO8859-15@euro    it_IT.ISO8859-15
        it_IT.UTF-8@euro         it_IT.UTF-8
        nl_BE.ISO8859-15@euro    nl_BE.ISO8859-15
        nl_NL.ISO8859-15@euro    nl_NL.ISO8859-15
        pt_PT.ISO8859-15@euro    pt_PT.ISO8859-15
        cz                       cs_CZ.ISO8859-2
        cs_CZ                    cs_CZ.ISO8859-2
        cs_CZ.ISO8859-2          cs_CZ.ISO8859-2
        cs_CZ.UTF-8              cs_CZ.UTF-8
        cs_CZ.UTF-8@euro         cs_CZ.UTF-8
        ko_KR.EUC                ko_KR.EUC
        ko_KR.UTF-8              ko_KR.UTF-8
        zh_CN.EUC                zh_CN.EUC
        zh_CN.GBK                zh_CN.GBK
        zh_CN.UTF-8              zh_CN.UTF-8
        zh_TW.EUC                zh_TW.EUC

        )}->{$LANG} || $LANG;

        if ($lang eq 'ko_KR.EUC') {
            $encoding = 'UHC';
        }
        elsif ($lang eq 'zh_CN.EUC') {
            $encoding = 'GBK';
        }
        elsif ($lang eq 'zh_TW.EUC') {
            $encoding = 'N/A';
        }
        elsif (my($codeset) = $lang =~ m/\A [^.]+ \. ([^@]+) /oxms) {
            $encoding = {qw(

            5601         UHC
            ANSI1251     N/A
            BIG5         Big5Plus
            BIG5HK       Big5HKSCS
            EUC          N/A
            GB18030      GB18030
            GBK          GBK
            ISO/IEC646   USASCII
            ISO8859-1    Latin1
            ISO8859-13   Latin7
            ISO8859-15   Latin9
            ISO8859-2    Latin2
            ISO8859-5    Cyrillic
            ISO8859-6    Arabic
            ISO8859-7    Greek
            ISO8859-8    Hebrew
            ISO8859-9    Latin5
            KOI8-R       KOI8R
            PCK          Sjis
            TIS620       TIS620
            TIS620-2533  TIS620
            UTF-8        UTF2
            cns11643     N/A
            eucJP        EUCJP
            gb2312       GBK

            )}->{$codeset};
        }
    }

    # HP HP-UX
    elsif ($OSNAME eq 'hpux') {

        # HP-UX 9.x
        if ($LANG =~ m/\A japanese \z/oxms) {
            $encoding = 'Sjis';
        }
        elsif ($LANG =~ m/\A japanese\.euc \z/oxms) {
            $encoding = 'EUCJP';
        }

        # HP-UX 10.x
        if ($LANG =~ m/\A ja_JP\.SJIS \z/oxms) {
            $encoding = 'Sjis';
        }
        elsif ($LANG =~ m/\A ja_JP\.eucJP \z/oxms) {
            $encoding = 'EUCJP';
        }

        # HP-UX 11.x
        elsif (my($codeset) = $LANG =~ m/\A [^.]+ \. ([^@]+) /oxms) {
            $encoding = {

            # HP-UX 11i v3 Internationalization Features
            # Appendix -- Summary of Locale and codeset Conversion Support in HP-UX 11i v3
            # Locales

            qw(

            SJIS       Sjis
            arabic8    N/A
            big5       Big5Plus
            ccdc       N/A
            cp1251     N/A
            eucJP      EUCJP
            eucKR      UHC
            eucTW      N/A
            gb18030    GB18030
            greek8     N/A
            hebrew8    N/A
            hkbig5     Big5HKSCS
            hp15CN     N/A
            iso88591   Latin1
            iso885910  Latin6
            iso885911  TIS620
            iso885913  Latin7
            iso885915  Latin9
            iso88592   Latin2
            iso88593   Latin3
            iso88594   Latin4
            iso88595   Cyrillic
            iso88596   Arabic
            iso88597   Greek
            iso88598   Hebrew
            iso88599   Latin5
            kana8      N/A
            koi8r      KOI8R
            roman8     N/A
            tis620     TIS620
            turkish8   N/A
            utf8       UTF2

            )}->{$codeset};
        }
    }

    # IBM AIX
    elsif ($OSNAME eq 'aix') {
        my $codeset = {

        # SC23-4902-03
        # AIX 5L Version 5.3
        # National Language Support Guide and Reference
        # (c) Copyright International Business Machines Corporation 2002, 2006. All rights reserved.

        qw(

        ar_AA           ISO8859-6
        AR_AA           UTF-8
        Ar_AA           IBM-1046
        ar_AE           ISO8859-6
        AR_AE           UTF-8
        ar_DZ           ISO8859-6
        AR_DZ           UTF-8
        ar_BH           ISO8859-6
        AR_BH           UTF-8
        ar_EG           ISO8859-6
        AR_EG           UTF-8
        ar_JO           ISO8859-6
        AR_JO           UTF-8
        ar_KW           ISO8859-6
        AR_KW           UTF-8
        ar_LB           ISO8859-6
        AR_LB           UTF-8
        ar_MA           ISO8859-6
        AR_MA           UTF-8
        ar_OM           ISO8859-6
        AR_OM           UTF-8
        ar_QA           ISO8859-6
        AR_QA           UTF-8
        ar_SA           ISO8859-6
        AR_SA           UTF-8
        ar_SY           ISO8859-6
        AR_SY           UTF-8
        ar_TN           ISO8859-6
        AR_TN           UTF-8
        ar_YE           ISO8859-6
        AR_YE           UTF-8
        sq_AL           ISO8859-1
        sq_AL.8859-15   ISO8859-15
        SQ_AL           UTF-8
        be_BY           ISO8859-5
        BE_BY           UTF-8
        bg_BG           ISO8859-5
        BG_BG           UTF-8
        ca_ES.IBM-1252  IBM-1252
        ca_ES           ISO8859-1
        ca_ES.8859-15   ISO8859-15
        CA_ES           UTF-8
        Ca_ES           IBM-850
        zh_TW           IBM-eucTW
        ZH_TW           UTF-8
        Zh_TW           big5
        zh_CN           IBM-eucCN
        ZH_CN           UTF-8
        Zh_CN           GBK/GB18030
        ZH_HK           UTF-8
        ZH_SG           UTF-8
        hr_HR           ISO8859-2
        HR_HR           UTF-8
        cs_CZ           ISO8859-2
        CS_CZ           UTF-8
        da_DK           ISO8859-1
        da_DK.8859-15   ISO8859-15
        DA_DK           UTF-8
        nl_BE.IBM-1252  IBM-1252
        nl_BE           ISO8859-1
        nl_BE.8859-15   ISO8859-15
        NL_BE           UTF-8
        nl_NL.IBM-1252  IBM-1252
        nl_NL           ISO8859-1
        nl_NL.8859-15   ISO8859-15
        NL_NL           UTF-8
        en_AU.8859-15   ISO8859-15
        EN_AU           UTF-8
        en_BE.8859-15   ISO8859-15
        EN_BE           UTF-8
        en_CA.8859-15   ISO8859-15
        EN_CA           UTF-8
        en_GB.IBM-1252  IBM-1252
        en_GB           ISO8859-1
        en_GB.8859-15   ISO8859-15
        EN_GB           UTF-8
        en_HK           ISO8859-15
        EN_HK           UTF-8
        en_IE.8859-15   ISO8859-15
        EN_IE           UTF-8
        en_IN.8859-15   ISO8859-15
        EN_IN           UTF-8
        en_NZ.8859-15   ISO8859-15
        EN_NZ           UTF-8
        en_PH           ISO8859-15
        EN_PH           UTF-8
        en_SG           ISO8859-15
        EN_SG           UTF-8
        en_US           ISO8859-1
        en_US.8859-15   ISO8859-15
        EN_US           UTF-8
        en_ZA.8859-15   ISO8859-15
        EN_ZA           UTF-8
        Et_EE           IBM-922
        et_EE           ISO8859-4
        ET_EE           UTF-8
        fi_FI.IBM-1252  IBM-1252
        fi_FI           ISO8859-1
        fi_FI.8859-15   ISO8859-15
        FI_FI           UTF-8
        fr_BE.IBM-1252  IBM-1252
        fr_BE           ISO8859-1
        fr_BE.8859-15   ISO8859-15
        FR_BE           UTF-8
        fr_CA           ISO8859-1
        fr_CA.8859-15   ISO8859-15
        FR_CA           UTF-8
        fr_FR.IBM-1252  IBM-1252
        fr_FR           ISO8859-1
        fr_FR.8859-15   ISO8859-15
        FR_FR           UTF-8
        fr_LU.8859-15   ISO8859-1
        FR_LU           ISO8859-1
        fr_CH           ISO8859-1
        fr_CH.8859-15   ISO8859-15
        FR_CH           UTF-8
        de_AT.8859-15   ISO8859-15
        DE_AT           UTF-8
        de_CH           ISO8859-1
        de_CH.8859-15   ISO8859-15
        DE_CH           UTF-8
        de_DE.IBM-1252  IBM-1252
        de_DE           ISO8859-1
        de_DE.8859-15   ISO8859-15
        DE_DE           UTF-8
        de_LU.8859-15   ISO8859-15
        DE_LU           UTF-8
        el_GR           ISO8859-7
        EL_GR           UTF-8
        iw_IL           ISO8859-8
        HE_IL           UTF-8
        Iw_IL           IBM-856
        hu_HU           ISO8859-2
        HU_HU           UTF-8
        is_IS           ISO8859-1
        is_IS.8859-15   ISO8859-15
        IS_IS           UTF-8
        AS_IN           UTF-8
        BN_IN           UTF-8
        GU_IN           UTF-8
        HI_IN           UTF-8
        KN_IN           UTF-8
        ML_IN           UTF-8
        MR_IN           UTF-8
        OR_IN           UTF-8
        PA_IN           UTF-8
        TA_IN           UTF-8
        TE_IN           UTF-8
        it_IT.IBM-1252  IBM-1252
        it_IT           ISO8859-1
        it_IT.8859-15   ISO8859-15
        IT_IT           UTF-8
        it_CH.8859-15   ISO8859-15
        IT_CH           UTF-8
        ja_JP           IBM-eucJP
        JA_JP           UTF-8
        Ja_JP           IBM-943
        KK_KZ           UTF-8
        ko_KR           IBM-eucKR
        KO_KR           UTF-8
        id_ID           ISO8859-15
        ID_ID           UTF-8
        Lv_LV           IBM-921
        lv_LV           ISO8859-4
        LV_LV           UTF-8
        Lt_LT           IBM-921
        lt_LT           ISO8859-4
        LT_LT           UTF-8
        mk_MK           ISO8859-5
        MK_MK           UTF-8
        ms_MY           ISO8859-15
        MS_MY           UTF-8
        no_NO           ISO8859-1
        no_NO.8859-15   ISO8859-15
        NO_NO           UTF-8
        pl_PL           ISO8859-2
        PL_PL           UTF-8
        pt_BR           ISO8859-1
        pt_BR.8859-15   ISO8859-15
        PT_BR           UTF-8
        pt_PT.IBM-1252  IBM-1252
        pt_PT           ISO8859-1
        pt_PT.8859-15   ISO8859-15
        PT_PT           UTF-8
        ro_RO           ISO8859-2
        RO_RO           UTF-8
        ru_RU           ISO8859-5
        RU_RU           UTF-8
        sr_SP           ISO8859-5
        SR_SP           UTF-8
        sr_YU           ISO8859-5
        SR_YU           UTF-8
        sh_SP           ISO8859-2
        SH_SP           UTF-8
        sh_YU           ISO8859-2
        SH_YU           UTF-8
        sk_SK           ISO8859-2
        SK_SK           UTF-8
        sl_SI           ISO8859-2
        SL_SI           UTF-8
        es_AR.8859-15   ISO8859-15
        ES_AR           UTF-8
        es_BO           ISO8859-15
        ES_BO           UTF-8
        es_CL.8859-15   ISO8859-15
        ES_CL           UTF-8
        es_CO.8859-15   ISO8859-15
        ES_CO           UTF-8
        es_CR           ISO8859-15
        ES_CR           UTF-8
        es_DO           ISO8859-15
        ES_DO           UTF-8
        es_EC           ISO8859-15
        ES_EC           UTF-8
        es_GT           ISO8859-15
        ES_GT           UTF-8
        es_HN           ISO8859-15
        ES_HN           UTF-8
        es_ES.IBM-1252  IBM-1252
        es_ES           ISO8859-1
        es_ES.8859-15   ISO8859-15
        ES_ES           UTF-8
        es_MX.8859-15   ISO8859-15
        ES_MX           UTF-8
        es_NI           ISO8859-15
        ES_NI           UTF-8
        es_PA           ISO8859-15
        ES_PA           UTF-8
        es_PY           ISO8859-15
        ES_PY           UTF-8
        es_PE.8859-15   ISO8859-15
        ES_PE           UTF-8
        es_PR.8859-15   ISO8859-15
        ES_PR           UTF-8
        es_US           ISO8859-15
        ES_US           UTF-8
        es_UY.8859-15   ISO8859-15
        ES_UY           UTF-8
        es_VE.8859-15   ISO8859-15
        ES_VE           UTF-8
        sv_SE           ISO8859-1
        sv_SE.8859-15   ISO8859-15
        SV_SE           UTF-8
        th_TH           TIS-620
        TH_TH           UTF-8
        tr_TR           ISO8859-9
        TR_TR           UTF-8
        Uk_UA           IBM-1124
        UK_UA           UTF-8
        Vi_VN           IBM-1129
        VI_VN           UTF-8

        )}->{$LANG};

        $encoding = {qw(

        GBK/GB18030  GB18030
        IBM-1046     N/A
        IBM-1124     N/A
        IBM-1129     N/A
        IBM-1252     N/A
        IBM-850      N/A
        IBM-856      N/A
        IBM-921      N/A
        IBM-922      N/A
        IBM-943      Sjis
        IBM-eucCN    GBK
        IBM-eucJP    EUCJP
        IBM-eucKR    UHC
        IBM-eucTW    N/A
        ISO8859-1    Latin1
        ISO8859-15   Latin9
        ISO8859-2    Latin2
        ISO8859-4    Latin4
        ISO8859-5    Cyrillic
        ISO8859-6    Arabic
        ISO8859-7    Greek
        ISO8859-8    Hebrew
        ISO8859-9    Latin5
        TIS-620      TIS620
        UTF-8        UTF2
        big5         Big5Plus

        )}->{$codeset};
    }

    # Other Systems
    if ($encoding eq '') {
        if ($encoding = {qw(

            ja            EUCJP
            ja_JP         EUCJP
            ja_JP.ujis    EUCJP
            ja_JP.eucJP   EUCJP
            Jp_JP         EUCJP
            ja_JP.AJEC    EUCJP
            ja_JP.EUC     EUCJP
            ja_JP.mscode  Sjis
            ja_JP.SJIS    Sjis
            ja_JP.PCK     Sjis
            ja_JP.UTF-8   UTF2
            ja_JP.utf8    UTF2
            japanese      Sjis
            japanese.euc  EUCJP
            japan         EUCJP
            Japanese-EUC  EUCJP

            )}->{$LANG}) {
        }
        elsif (my($codeset) = $LANG =~ m/\A [^.]+ \. ([^@]+) /oxms) {
            $encoding = {qw(

            UTF-8        UTF2
            UTF8         UTF2
            ISO_8859-1   Latin1
            ISO_8859-2   Latin2
            ISO_8859-3   Latin3
            ISO_8859-4   Latin4
            ISO_8859-5   Cyrillic
            ISO_8859-6   Arabic
            ISO_8859-7   Greek
            ISO_8859-8   Hebrew
            ISO_8859-9   Latin5
            ISO_8859-10  Latin6
            ISO_8859-11  TIS620
            ISO_8859-13  Latin7
            ISO_8859-14  Latin8
            ISO_8859-15  Latin9
            ISO_8859-16  Latin10
            ISO-8859-1   Latin1
            ISO-8859-2   Latin2
            ISO-8859-3   Latin3
            ISO-8859-4   Latin4
            ISO-8859-5   Cyrillic
            ISO-8859-6   Arabic
            ISO-8859-7   Greek
            ISO-8859-8   Hebrew
            ISO-8859-9   Latin5
            ISO-8859-10  Latin6
            ISO-8859-11  TIS620
            ISO-8859-13  Latin7
            ISO-8859-14  Latin8
            ISO-8859-15  Latin9
            ISO-8859-16  Latin10
            ISO8859-1    Latin1
            ISO8859-2    Latin2
            ISO8859-3    Latin3
            ISO8859-4    Latin4
            ISO8859-5    Cyrillic
            ISO8859-6    Arabic
            ISO8859-7    Greek
            ISO8859-8    Hebrew
            ISO8859-9    Latin5
            ISO8859-10   Latin6
            ISO8859-11   TIS620
            ISO8859-13   Latin7
            ISO8859-14   Latin8
            ISO8859-15   Latin9
            ISO8859-16   Latin10
            ISO88591     Latin1
            ISO88592     Latin2
            ISO88593     Latin3
            ISO88594     Latin4
            ISO88595     Cyrillic
            ISO88596     Arabic
            ISO88597     Greek
            ISO88598     Hebrew
            ISO88599     Latin5
            ISO885910    Latin6
            ISO885911    TIS620
            ISO885913    Latin7
            ISO885914    Latin8
            ISO885915    Latin9
            ISO885916    Latin10
            KOI8-R       KOI8R
            KOI8-U       KOI8U

            )}->{uc $codeset};
        }
    }

    return $encoding;
}

#
# get absolute path to filter software
#
sub abspath {
    my($encoding) = @_;
    for my $path (@INC) {
        if ($OSNAME eq 'MacOS') {
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
  use Char ver.sion;             --- requires minimum version
  use Char ver.sion.0;           --- expects version (match or die)

  subroutines:
    Char::ord(...);
    Char::reverse(...);
    Char::getc(...);
    Char::length(...);
    Char::substr(...);
    Char::index(...);
    Char::rindex(...);

  # "no Char;" not supported

=head1 SOFTWARE COMPOSITION

   Char.pm --- Character Oriented Perl by Magic Comment

=head1 OTHER SOFTWARE

To using this software, you must get filter software of 'Sjis software family'.
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
description from anywhere of the script.

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
  ascii               USASCII
  usascii             USASCII
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
  jisc6220            JIS8
  jisx0201            JIS8
  jis8                JIS8
  ank                 JIS8
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
  kps9566             KPS9566
  kps95662003         KPS9566
  kps95662000         KPS9566
  kps95661997         KPS9566
  kps956697           KPS9566
  euckp               KPS9566
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
  latin2              Latin2
  isoiec88592         Latin2
  iso88592            Latin2
  iec88592            Latin2
  latin3              Latin3
  isoiec88593         Latin3
  iso88593            Latin3
  iec88593            Latin3
  latin4              Latin4
  isoiec88594         Latin4
  iso88594            Latin4
  iec88594            Latin4
  cyrillic            Cyrillic
  isoiec88595         Cyrillic
  iso88595            Cyrillic
  iec88595            Cyrillic
  koi8r               KOI8R
  koi8u               KOI8U
  arabic              Arabic
  isoiec88596         Arabic
  iso88596            Arabic
  iec88596            Arabic
  greek               Greek
  isoiec88597         Greek
  iso88597            Greek
  iec88597            Greek
  hebrew              Hebrew
  isoiec88598         Hebrew
  iso88598            Hebrew
  iec88598            Hebrew
  latin5              Latin5
  isoiec88599         Latin5
  iso88599            Latin5
  iec88599            Latin5
  latin6              Latin6
  isoiec885910        Latin6
  iso885910           Latin6
  iec885910           Latin6
  tis620              TIS620
  tis6202533          TIS620
  isoiec885911        TIS620
  iso885911           TIS620
  iec885911           TIS620
  latin7              Latin7
  isoiec885913        Latin7
  iso885913           Latin7
  iec885913           Latin7
  latin8              Latin8
  isoiec885914        Latin8
  iso885914           Latin8
  iec885914           Latin8
  latin9              Latin9
  isoiec885915        Latin9
  iso885915           Latin9
  iec885915           Latin9
  latin10             Latin10
  isoiec885916        Latin10
  iso885916           Latin10
  iec885916           Latin10
  windows1252         Windows1252
  windows1258         Windows1258
  -----------------------------------

=head1 CHARACTER ORIENTED SUBROUTINES

=over 2

=item * Order of Character

  $ord = Char::ord($string);

  This subroutine returns the numeric value (ASCII or Multibyte Character) of the
  first character of $string. The return value is always unsigned.

=item * Reverse List or String

  @reverse = Char::reverse(@list);
  $reverse = Char::reverse(@list);

  In list context, this subroutine returns a list value consisting of the elements
  of @list in the opposite order. The subroutine can be used to create descending
  sequences:

  for (Char::reverse(1 .. 10)) { ... }

  Because of the way hashes flatten into lists when passed as a @list, reverse can
  also be used to invert a hash, presuming the values are unique:

  %barfoo = Char::reverse(%foobar);

  In scalar context, the subroutine concatenates all the elements of LIST and then
  returns the reverse of that resulting string, character by character.

=item * Returns Next Character

  $getc = Char::getc(FILEHANDLE);
  $getc = Char::getc($filehandle);
  $getc = Char::getc;

  This subroutine returns the next character from the input file attached to
  FILEHANDLE. It returns undef at end-of-file, or if an I/O error was encountered.
  If FILEHANDLE is omitted, the subroutine reads from STDIN.

  This subroutine is somewhat slow, but it's occasionally useful for single-character
  input from the keyboard -- provided you manage to get your keyboard input
  unbuffered. This subroutine requests unbuffered input from the standard I/O library.
  Unfortunately, the standard I/O library is not so standard as to provide a portable
  way to tell the underlying operating system to supply unbuffered keyboard input to
  the standard I/O system. To do that, you have to be slightly more clever, and in
  an operating-system-dependent fashion. Under Unix you might say this:

  if ($BSD_STYLE) {
      system "stty cbreak </dev/tty >/dev/tty 2>&1";
  }
  else {
      system "stty", "-icanon", "eol", "\001";
  }

  $key = Char::getc;

  if ($BSD_STYLE) {
      system "stty -cbreak </dev/tty >/dev/tty 2>&1";
  }
  else {
      system "stty", "icanon", "eol", "^@"; # ASCII NUL
  }
  print "\n";

  This code puts the next character typed on the terminal in the string $key. If your
  stty program has options like cbreak, you'll need to use the code where $BSD_STYLE
  is true. Otherwise, you'll need to use the code where it is false.

=item * Length by Character

  $length = Char::length($string);
  $length = Char::length();

  This subroutine returns the length in characters of the scalar value $string. If
  $string is omitted, it returns the Char::length of $_.

  Do not try to use length to find the size of an array or hash. Use scalar @array
  for the size of an array, and scalar keys %hash for the number of key/value pairs
  in a hash. (The scalar is typically omitted when redundant.)

  To find the length of a string in bytes rather than characters, say:

  $blen = length($string);

  or

  $blen = CORE::length($string);

=item * Substr by Character

  $substr = Char::substr($string,$offset,$length,$replacement);
  $substr = Char::substr($string,$offset,$length);
  $substr = Char::substr($string,$offset);

  This subroutine extracts a substring out of the string given by $string and
  returns it. The substring is extracted starting at $offset characters from the
  front of the string.
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

=item * Index by Character

  $index = Char::index($string,$substring,$offset);
  $index = Char::index($string,$substring);

  This subroutine searches for one string within another. It returns the position of
  the first occurrence of $substring in $string. The $offset, if specified, says how
  many characters from the start to skip before beginning to look. Positions are
  based at 0. If the substring is not found, the subroutine returns one less than
  the base, ordinarily -1. To work your way through a string, you might say:

  $pos = -1;
  while (($pos = Char::index($string, $lookfor, $pos)) > -1) {
      print "Found at $pos\n";
      $pos++;
  }

  Three Indexes
  -------------------------------------------------------------------------
  Function       Works as    Returns as   Description
  -------------------------------------------------------------------------
  index          Character   Byte         JPerl semantics (most useful)
  Char::index    Character   Character    Character-oriented semantics
  CORE::index    Byte        Byte         Byte-oriented semantics
  -------------------------------------------------------------------------

=item * Rindex by Character

  $rindex = Char::rindex($string,$substring,$position);
  $rindex = Char::rindex($string,$substring);

  This subroutine works just like Char::index except that it returns the position
  of the last occurrence of $substring in $string (a reverse index). The subroutine
  returns -1 if not $substring is found. $position, if specified, is the rightmost
  position that may be returned. To work your way through a string backward, say:

  $pos = Char::length($string);
  while (($pos = Char::rindex($string, $lookfor, $pos)) >= 0) {
      print "Found at $pos\n";
      $pos--;
  }

  Three Rindexes
  -------------------------------------------------------------------------
  Function       Works as    Returns as   Description
  -------------------------------------------------------------------------
  rindex         Character   Byte         JPerl semantics (most useful)
  Char::rindex   Character   Character    Character-oriented semantics
  CORE::rindex   Byte        Byte         Byte-oriented semantics
  -------------------------------------------------------------------------

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

 Other Tools
 http://search.cpan.org/dist/jacode/

 BackPAN
 http://backpan.perl.org/authors/id/I/IN/INA/

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

