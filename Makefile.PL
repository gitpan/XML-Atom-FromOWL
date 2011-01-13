use strict;
use warnings;

use inc::Module::Install;

my $dist = 'XML-Atom-FromOWL';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'common::sense'       => 0;
test_requires       'Module::Signature'   => '0.66';
requires            'namespace::clean'    => 0;
requires            'RDF::TrineShortcuts' => '0.100';
requires            'Scalar::Util'        => 0;
test_requires       'Test::More'          => '0.61';
requires            'XML::Atom::Content'  => 0;
requires            'XML::Atom::Entry'    => 0;
requires            'XML::Atom::Feed'     => 0;
requires            'XML::Atom::Link'     => 0;
requires            'XML::Atom::Person'   => 0;

resources(
	'homepage'   => "http://search.cpan.org/dist/$dist/",
	'repository' => "http://goddamn.co.uk/viewvc/perlmods/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);

keywords("Atom", "RDF", "Semantic Web", "OWL", "Feed");
	
write_doap_changes;
write_doap_changes_xml;

include 'Test::Signature';
auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
