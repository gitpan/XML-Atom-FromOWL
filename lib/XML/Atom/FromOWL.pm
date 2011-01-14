package XML::Atom::FromOWL;

use 5.008;
use common::sense;

use Data::UUID;
use RDF::TrineShortcuts qw[:all];
use Scalar::Util qw[blessed];
use XML::Atom::Content;
use XML::Atom::Entry;
use XML::Atom::Feed;
use XML::Atom::Link;
use XML::Atom::Person;

use constant ATOM => 'http://www.w3.org/2005/Atom';
sub AWOL { return 'http://bblfish.net/work/atom-owl/2006-06-06/#' . shift; }
sub AX   { return 'http://buzzword.org.uk/rdf/atomix#' . shift; }
sub FOAF { return 'http://xmlns.com/foaf/0.1/' . shift; }
sub LINK { return 'http://www.iana.org/assignments/relation/' . shift; }
sub RDF  { return 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' . shift; }
sub XSD  { return 'http://www.w3.org/2001/XMLSchema#' . shift; }

use namespace::clean;

our $VERSION;
our (%feed_dispatch, %entry_dispatch);

BEGIN
{
	$VERSION = '0.002';

	%feed_dispatch = (
		AWOL('entry')        => \&_export_feed_entry,
		AWOL('id')           => \&_export_thing_id,
		AWOL('title')        => \&_export_thing_TextConstruct,
		AWOL('subtitle')     => \&_export_thing_TextConstruct,
		AWOL('rights')       => \&_export_thing_TextConstruct,
		AWOL('updated')      => \&_export_thing_DateConstruct,
		AWOL('icon')         => \&_export_thing_ImageConstruct,
		AWOL('logo')         => \&_export_thing_ImageConstruct,
		AWOL('link')         => \&_export_thing_link,
		AWOL('author')       => \&_export_thing_PersonConstruct,
		AWOL('contributor')  => \&_export_thing_PersonConstruct,
		AWOL('category')     => \&_export_thing_category,
		);
	%entry_dispatch = (
		AWOL('id')           => \&_export_thing_id,
		AWOL('title')        => \&_export_thing_TextConstruct,
		AWOL('summary')      => \&_export_thing_TextConstruct,
		AWOL('rights')       => \&_export_thing_TextConstruct,
		AWOL('published')    => \&_export_thing_DateConstruct,
		AWOL('updated')      => \&_export_thing_DateConstruct,
		AWOL('link')         => \&_export_thing_link,
		AWOL('author')       => \&_export_thing_PersonConstruct,
		AWOL('contributor')  => \&_export_thing_PersonConstruct,
		AWOL('category')     => \&_export_thing_category,
		AWOL('content')      => \&_export_entry_content,
		# source
		);
}

sub new
{
	my ($class, %options) = @_;
	bless { %options }, $class;
}

sub export_feeds
{
	my ($self, $model, %options) = @_;
	$model = rdf_parse($model)
		unless blessed($model) && $model->isa('RDF::Trine::Model');
	
	my @subjects =  $model->subjects(rdf_resource(RDF('type')), rdf_resource(AWOL('Feed')));

	my @feeds;
	foreach my $s (@subjects)
	{
		push @feeds, $self->export_feed($model, $s, %options);
	}
	
	if ($options{sort} eq 'id')
	{
		return sort { $a->id cmp $b->id } @feeds;
	}
	return @feeds;
}

sub export_entries
{
	my ($self, $model, %options) = @_;
	$model = rdf_parse($model)
		unless blessed($model) && $model->isa('RDF::Trine::Model');
	
	my @subjects =  $model->subjects(rdf_resource(RDF('type')), rdf_resource(AWOL('Entry')));

	my @entries;
	foreach my $s (@subjects)
	{
		push @entries, $self->export_feed($model, $s, %options);
	}
	
	if ($options{sort} eq 'id')
	{
		return sort { $a->id cmp $b->id } @entries;
	}
	return @entries;
}

sub export_feed
{
	my ($self, $model, $subject, %options) = @_;
	$model = rdf_parse($model)
		unless blessed($model) && $model->isa('RDF::Trine::Model');
	
	my $feed = XML::Atom::Feed->new(Version => 1.0);

	my $attr = {
		version => $VERSION,
		uri     => 'http://search.cpan.org/dist/'.__PACKAGE__.'/',
		};
	$attr->{uri} =~ s/::/-/g;
	$feed->set(ATOM(), 'generator', __PACKAGE__, $attr, 1);

	my $triples = $model->get_statements($subject, undef, undef);
	while (my $triple = $triples->next)
	{
#		warn("FEED: ".$triple->sse);
		if (defined $feed_dispatch{$triple->predicate->uri}
		and ref($feed_dispatch{$triple->predicate->uri}) eq 'CODE')
		{
			my $code = $feed_dispatch{$triple->predicate->uri};
			$code->($self, $feed, $model, $triple, %options);
		}
		else
		{
#			warn("FEED: " . $triple->predicate->uri . " not implemented yet!");
		}
	}

	$feed->id( $self->_make_id ) unless $feed->id;

	return $feed;
}

sub export_entry
{
	my ($self, $model, $subject, %options) = @_;
	$model = rdf_parse($model)
		unless blessed($model) && $model->isa('RDF::Trine::Model');
	
	my $entry = XML::Atom::Entry->new(Version => 1.0);

	my $triples = $model->get_statements($subject, undef, undef);
	while (my $triple = $triples->next)
	{
#		warn("ENTRY: ".$triple->sse);		
		if (defined $entry_dispatch{$triple->predicate->uri}
		and ref($entry_dispatch{$triple->predicate->uri}) eq 'CODE')
		{
			my $code = $entry_dispatch{$triple->predicate->uri};
			$code->($self, $entry, $model, $triple, %options);
		}
		else
		{
#			warn("ENTRY: " . $triple->predicate->uri . " not implemented yet!");
		}
	}

	$entry->id( $self->_make_id ) unless $entry->id;

	return $entry;
}

sub _export_feed_entry
{
	my ($self, $feed, $model, $triple, %options) = @_;
	my $entry = $self->export_entry($model, $triple->object, %options);
	$feed->add_entry($entry);
}

sub _export_thing_id
{
	my ($self, $thing, $model, $triple, %options) = @_;
	unless ($triple->object->is_blank)
	{
		return $thing->id( flatten_node($triple->object) );
	}
}

sub _export_thing_link
{
	my ($self, $thing, $model, $triple, %options) = @_;
	
	my $link = XML::Atom::Link->new(Version => 1.0);
	
	my $iter = $model->get_statements($triple->object);
	while (my $st = $iter->next)
	{
		if ($st->predicate->uri eq AWOL('rel')
		and $st->object->is_resource)
		{
			(my $rel = $st->object->uri)
				=~ s'^http://www\.iana\.org/assignments/relation/'';
			$link->rel($rel);
		}
		elsif ($st->predicate->uri eq AWOL('to'))
		{
			my $iter2 = $model->get_statements($st->object);
			while (my $st2 = $iter2->next)
			{
				if ($st2->predicate->uri eq AWOL('type')
				and $st2->object->is_literal)
				{
					$link->type(flatten_node($st2->object));
				}
				elsif ($st2->predicate->uri eq AWOL('src')
				and !$st2->object->is_blank)
				{
					$link->href(flatten_node($st2->object));
				}
				elsif ($st2->predicate->uri eq AWOL('lang')
				and $st2->object->is_literal)
				{
					$link->hreflang(flatten_node($st2->object));
				}
			}
		}
	}
	
	return $thing->add_link($link);
}

sub _export_thing_PersonConstruct
{
	my ($self, $thing, $model, $triple, %options) = @_;
	
	my $person = XML::Atom::Person->new(Version => 1.0);
	
	my $iter = $model->get_statements($triple->object);
	while (my $st = $iter->next)
	{
		if ($st->predicate->uri eq AWOL('email')
		and !$st->object->is_blank)
		{
			(my $e = flatten_node($st->object)) =~ s'^mailto:'';
			$person->email($e);
		}
		elsif ($st->predicate->uri eq AWOL('uri')
		and !$st->object->is_blank)
		{
			$person->url(flatten_node($st->object));
		}
		elsif ($st->predicate->uri eq AWOL('name')
		and $st->object->is_literal)
		{
			$person->name(flatten_node($st->object));
		}
	}
	
	if ($triple->predicate->uri eq AWOL('contributor'))
	{
		return $thing->add_contributor($person);
	}
	if ($triple->predicate->uri eq AWOL('author'))
	{
		return $thing->add_author($person);
	}
}

sub _export_entry_content
{
	my ($self, $entry, $model, $triple, %options) = @_;
	
	my $content = XML::Atom::Content->new(Version => 1.0);
	if ($triple->object->is_literal)
	{
		$content->body(flatten_node($triple->object));
		$content->lang($triple->object->literal_value_language)
			if $triple->object->has_language;
	}
	else
	{
		my $iter = $model->get_statements($triple->object);
		while (my $st = $iter->next)
		{
			if ($st->predicate->uri eq AWOL('base')
			and !$st->object->is_blank)
			{
				$content->base(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('type')
			and $st->object->is_literal)
			{
				$content->type(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('lang')
			and $st->object->is_literal)
			{
				$content->lang(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('body')
			and $st->object->is_literal)
			{
				$content->body(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('src')
			and !$st->object->is_blank)
			{
				$content->set_attr(src => flatten_node($st->object));
			}
		}
	}
	
	return $entry->content($content);
}

sub _export_thing_category
{
	my ($self, $thing, $model, $triple, %options) = @_;
	
	my $category = XML::Atom::Category->new(Version => 1.0);

	if ($triple->object->is_literal)
	{
		$category->term(flatten_node($triple->object));
	}
	else
	{
		my $iter = $model->get_statements($triple->object);
		while (my $st = $iter->next)
		{
			if ($st->predicate->uri eq AWOL('term')
			and $st->object->is_literal)
			{
				$category->term(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('scheme')
			and !$st->object->is_blank)
			{
				$category->scheme(flatten_node($st->object));
			}
			elsif ($st->predicate->uri eq AWOL('label')
			and $st->object->is_literal)
			{
				$category->label(flatten_node($st->object));
				$category->set_attr('xml:lang', $st->object->literal_value_language)
					if $st->object->has_language;
			}
		}
	}
	
	return $thing->add_category($category);
}

sub _export_thing_TextConstruct
{
	my ($self, $thing, $model, $triple, %options) = @_;

	my $tag = {
		AWOL('title')     => 'title',
		AWOL('subtitle')  => 'subtitle',
		AWOL('summary')   => 'summary',
		AWOL('rights')    => 'rights',
		}->{$triple->predicate->uri};
	
	if ($triple->object->is_literal)
	{
		my $attr = { type=>'text' };
		$attr->{'xml:lang'} = $triple->object->literal_value_language
			if $triple->object->has_language;
		return $thing->set(ATOM(), $tag, flatten_node($triple->object), $attr, 1);
	}
	else
	{
		foreach my $fmt (qw(text html xhtml)) # TODO: does 'xhtml' need special handling??
		{
			my $iter = $model->get_statements(
				$triple->object,
				rdf_resource(AWOL($fmt)),
				undef,
				);
			while (my $st = $iter->next)
			{
				if ($st->object->is_literal)
				{
					my $attr = { type=>$fmt };
					$attr->{'xml:lang'} = $st->object->literal_value_language
						if $st->object->has_language;
					return $thing->set(ATOM(), $tag, flatten_node($st->object), $attr, 1);
				}
			}
		}
	}
}

sub _export_thing_DateConstruct
{
	my ($self, $thing, $model, $triple, %options) = @_;

	my $tag = {
		AWOL('published') => 'published',
		AWOL('updated')   => 'updated',
		}->{$triple->predicate->uri};
	
	if ($triple->object->is_literal)
	{
		my $attr = {};
		return $thing->set(ATOM(), $tag, flatten_node($triple->object), $attr, 1);
	}
}

sub _export_thing_ImageConstruct
{
	my ($self, $thing, $model, $triple, %options) = @_;

	my $tag = {
		AWOL('logo') => 'logo',
		AWOL('icon') => 'icon',
		}->{$triple->predicate->uri};
	
	if ($triple->object->is_resource)
	{
		my $attr = {};
		return $thing->set(ATOM(), $tag, flatten_node($triple->object), $attr, 1);
	}
}

sub _make_id
{
	my ($self) = @_;
	$self->{uuid} ||= Data::UUID->new;
	return 'urn:uuid:'.$self->{uuid}->create_str;
}

1;

__END__

=head1 NAME

XML::Atom::FromOWL - export RDF data to Atom

=head1 SYNOPSIS

 use LWP::UserAgent;
 use XML::Atom::OWL;
 use XML::Atom::FromOWL;
 
 my $ua       = LWP::UserAgent->new;
 my $r        = $ua->get('http://intertwingly.net/blog/index.atom');
 my $atomowl  = XML::Atom::OWL->new($r->decoded_content, $r->base);
 my $model    = $atomowl->consume->graph;  ## an RDF::Trine::Model
 
 my $exporter = XML::Atom::FromOWL->new;
 print $_->as_xml
	foreach $exporter->export_feeds($model);

=head1 DESCRIPTION

This module reads RDF and writes Atom feeds. It does the reverse
of L<XML::Atom::OWL>.

=head2 Constructor

=over

=item * C<< new(%options) >>

Returns a new XML::Atom::FromOWL object.

There are no valid options at the moment - the hash is reserved
for future use.

=back

=head2 Methods

=over

=item * C<< export_feeds($input, %options) >>

Returns a list of feeds found in the input, in no particular order.

The input may be a URI, file name, L<RDF::Trine::Model> or anything else
that can be handled by the C<rdf_parse> method of L<RDF::TrineShortcuts>.

Each item in the list returned is an L<XML::Atom::Feed>.

=item * C<< export_feed($input, $subject, %options) >>

As per C<export_feeds> but exports just a single feed.

The subject provided must be an RDF::Trine::Node::Blank or
RDF::Trine::Node::Resource of type awol:Feed.

=item * C<< export_entries($input, %options) >>

Returns a list of entries found in the input, in no particular order.

The input may be a URI, file name, L<RDF::Trine::Model> or anything else
that can be handled by the C<rdf_parse> method of L<RDF::TrineShortcuts>.

Each item in the list returned is an L<XML::Atom::Entry>.

=item * C<< export_entry($input, $subject, %options) >>

As per C<export_entry> but exports just a single entry.

The subject provided must be an RDF::Trine::Node::Blank or
RDF::Trine::Node::Resource of type awol:Entry.

=back

=head2 RDF Input

Input is expected to use AtomOwl
L<http://bblfish.net/work/atom-owl/2006-06-06/#>.

=head2 Feed Output

This module doesn't attempt to enforce many of OWL's semantic
constraints (e.g. it doesn't enforce that an entry has only one
title). It relies on L<XML::Atom::Feed> and L<XML::Atom::Entry>
for that sort of thing, but if your input is sensible that
shouldn't be a problem.

=head1 SEE ALSO

L<XML::Atom::OWL>, L<HTML::Microformats>, L<RDF::TrineShortcuts>,
L<XML::Atom::Feed>, L<XML::Atom::Entry>.

L<http://bblfish.net/work/atom-owl/2006-06-06/>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2011 Toby Inkster

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
