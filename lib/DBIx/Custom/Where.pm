package DBIx::Custom::Where;

use strict;
use warnings;

use base 'Object::Simple';

use overload 'bool' => sub {1}, fallback => 1;
use overload '""' => sub { shift->to_string }, fallback => 1;

use Carp 'croak';

__PACKAGE__->attr(
  'query_builder',
  clause => sub { [] },
  param => sub { {} }
);

sub to_string {
    my $self = shift;
    
    my $clause = $self->clause;
    $clause = ['and', $clause] unless ref $clause eq 'ARRAY';
    $clause->[0] = 'and' unless @$clause;

    my $where = [];
    my $count = {};
    $self->_forward($clause, $where, $count, 'and');

    unshift @$where, 'where' if @$where;
    
    return join(' ', @$where);
}

our %VALID_OPERATIONS = map { $_ => 1 } qw/and or/;

sub _forward {
    my ($self, $clause, $where, $count, $op) = @_;
    
    if (ref $clause eq 'ARRAY') {
        push @$where, '(';
        
        my $op = $clause->[0] || '';
        
        croak qq{"$op" is invalid operation}
          unless $VALID_OPERATIONS{$op};
          
        for (my $i = 1; $i < @$clause; $i++) {
            my $pushed = $self->_forward($clause->[$i], $where, $count, $op);
            push @$where, $op if $pushed;
        }
        
        pop @$where if $where->[-1] eq $op;
        
        if ($where->[-1] eq '(') {
            pop @$where;
            pop @$where;
        }
        else {
            push @$where, ')';
        }
    }
    else {
        
        # Column
        my $columns = $self->query_builder->build_query($clause)->columns;
        croak qq{each tag contains one column name: tag "$clause"}
          unless @$columns == 1;
        my $column = $columns->[0];
        
        # Count up
        my $count = ++$count->{$column};
        
        # Push element
        my $param    = $self->param;
        my $pushed;
        if (exists $param->{$column}) {
            if (ref $param->{$column} eq 'ARRAY') {
                $pushed = 1 if exists $param->{$column}->[$count - 1];
            }
            elsif ($count == 1) {
                $pushed = 1;
            }
        }
        
        push @$where, $clause if $pushed;
        
        return $pushed;
    }
}

1;

=head1 NAME

DBIx::Custom::Where - Where clause

=head1 SYNOPSYS

    $where = DBIx::Custom::Where->new;
    
    my $sql = "select * from book $where";

=head1 ATTRIBUTES

=head2 C<param>

    my $param = $where->param;
    $where    = $where->param({title => 'Perl',
                               date => ['2010-11-11', '2011-03-05']},
                               name => ['Ken', 'Taro']);
=head1 METHODS

=head2 C<clause>

    $where->clause(title => '{= title}', date => ['{< date}', '{> date}']);

Where clause. These clauses is joined by ' and ' at C<to_string()>
if corresponding parameter name is exists in C<param>.

=head2 C<to_string>

    $where->to_string;
