use warnings;
use strict;
use Test::More;
use Reflex;

{
	package Contained;
	use Moose;
	extends 'Reflex::Base';

	sub foo {
		my ($self, $args) = @_;
		$self->emit(event => 'foo_event', args => $args);
	}
}

{
	package Container;
	use Moose;
	use Reflex::Callbacks('cb_method');
	extends 'Reflex::Base';

	has things => (is => 'ro', isa => 'HashRef', default => sub { {} });

	sub store {
		my ($self, $thing) = @_;
		$self->watch($thing, 'foo_event' => cb_method($self, 'foo_event'));
		$self->things->{$thing} = $thing;
	}

	sub remove {
		my ($self, $thing) = @_;
		$self->ignore($thing);
		delete($self->things->{$thing});
	}

	sub foo_event {
		my ($self, $args) = @_;
		$self->emit(event => 'foo_event', args => $args);
		$self->remove($args->{_sender}->get_last_emitter());
	}
}

{
	package Harness;
	use Moose;
	use Reflex::Callbacks('cb_method');
	extends 'Reflex::Base';

	has container => (
		is      => 'ro',
		isa     => 'Container',
		lazy    => 1,
		builder => '_build_container'
	);

	sub _build_container {
		my $self = shift;
		my $cont = Container->new();
		for (0 .. 9) {
			$cont->store(Contained->new());
		}

		$self->watch($cont, 'foo_event' => cb_method($self, 'foo_handler'));

		return $cont;
	}

	my $baz = 0;

	sub foo_handler {
		my ($self, $args) = @_;
		my $sender = $args->{_sender};
		Test::More::isa_ok(
			$sender, 'Reflex::Sender',
			'got the Reflex::Sender object'
		);
		my $source = $sender->get_first_emitter();
		Test::More::isa_ok($source, 'Contained', 'got the source of the event');
		my $last = $sender->get_last_emitter();
		Test::More::isa_ok(
			$last, 'Container',
			'got the final emitter in the stack'
		);
		my @all = $sender->get_all_emitters();
		Test::More::is(scalar(@all), 2, 'got the right number of emitters');

		if ($baz++ == 9) {
			$self->ignore($self->container);
		}
	}
}

my $harness = Harness->new();
foreach my $thing (values %{$harness->container->things}) {
	$thing->foo();
}

$harness->run_all();
done_testing();
