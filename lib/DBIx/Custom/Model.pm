package DBIx::Custom::Model;
use Object::Simple -base;

use Carp 'croak';
use DBIx::Custom::Util '_subname';

# Carp trust relationship
push @DBIx::Custom::CARP_NOT, __PACKAGE__;

has [qw/dbi table/],
    bind_type => sub { [] },
    columns => sub { [] },
    join => sub { [] },
    primary_key => sub { [] };

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;

    # Method name
    my ($package, $mname) = $AUTOLOAD =~ /^([\w\:]+)\:\:(\w+)$/;

    # Method
    $self->{_methods} ||= {};
    if (my $method = $self->{_methods}->{$mname}) {
        return $self->$method(@_)
    }
    elsif (my $dbi_method = $self->dbi->can($mname)) {
        $self->dbi->$dbi_method(@_);
    }
    elsif ($self->{dbh} && (my $dbh_method = $self->dbh->can($mname))) {
        $self->dbi->dbh->$dbh_method(@_);
    }
    else {
        croak qq{Can't locate object method "$mname" via "$package" }
            . _subname;
    }
}

my @methods = qw/insert insert_at update update_at update_all
                 delete delete_at delete_all select select_at/;
foreach my $method (@methods) {

    my $code = sub {
        my $self = shift;

        my @args = (
            table => $self->table,
            bind_type => $self->bind_type,
            primary_key => $self->primary_key,
            type => $self->type, # DEPRECATED!
        );
        push @args, (join => $self->join) if $method =~ /^select/;
        unshift @args, shift if @_ % 2;
        
        $self->dbi->$method(@args, @_);
    };
    
    no strict 'refs';
    my $class = __PACKAGE__;
    *{"${class}::$method"} = $code;
}

sub DESTROY { }

sub method {
    my $self = shift;
    
    # Merge
    my $methods = ref $_[0] eq 'HASH' ? $_[0] : {@_};
    $self->{_methods} = {%{$self->{_methods} || {}}, %$methods};
    
    return $self;
}

sub mycolumn {
    my $self = shift;
    my $table = shift unless ref $_[0];
    my $columns = shift;
    
    $table ||= $self->table || '';
    $columns ||= $self->columns;
    
    return $self->dbi->mycolumn($table, $columns);
}

sub new {
    my $self = shift->SUPER::new(@_);
    
    # Check attribute names
    my @attrs = keys %$self;
    foreach my $attr (@attrs) {
        croak qq{"$attr" is invalid attribute name } . _subname
          unless $self->can($attr);
    }
    
    return $self;
}

# DEPRECATED!
has 'filter';
has 'name';
has type => sub { [] };

1;

=head1 NAME

DBIx::Custom::Model - Model

=head1 SYNOPSIS

use DBIx::Custom::Table;

my $table = DBIx::Custom::Model->new(table => 'books');

=head1 ATTRIBUTES

=head2 C<dbi>

    my $dbi = $model->dbi;
    $model = $model->dbi($dbi);

L<DBIx::Custom> object.

=head2 C<join>

    my $join = $model->join;
    $model = $model->join(
        ['left outer join company on book.company_id = company.id']
    );
    
Join clause, this value is passed to C<select> method.

=head2 C<primary_key>

    my $primary_key = $model->primary_key;
    $model = $model->primary_key(['id', 'number']);

Primary key,this is passed to C<insert>, C<update>,
C<delete>, and C<select> method.

=head2 C<table>

    my $table = $model->table;
    $model = $model->table('book');

Table name, this is passed to C<select> method.

=head2 C<bind_type>

    my $type = $model->bind_type;
    $model = $model->bind_type(['image' => DBI::SQL_BLOB]);
    
Database data type, this is used as type optioon of C<insert>, 
C<update>, C<update_all>, C<delete>, C<delete_all>,
C<select>, and C<execute> method

=head1 METHODS

L<DBIx::Custom::Model> inherits all methods from L<Object::Simple>,
and you can use all methods of L<DBIx::Custom> and L<DBI>
and implements the following new ones.

=head2 C<delete>

    $table->delete(...);
    
Same as C<delete> of L<DBIx::Custom> except that
you don't have to specify C<table> option.

=head2 C<delete_all>

    $table->delete_all(...);
    
Same as C<delete_all> of L<DBIx::Custom> except that
you don't have to specify C<table> option.

=head2 C<insert>

    $table->insert(...);
    
Same as C<insert> of L<DBIx::Custom> except that
you don't have to specify C<table> option.

=head2 C<method>

    $model->method(
        update_or_insert => sub {
            my $self = shift;
            
            # ...
        },
        find_or_create   => sub {
            my $self = shift;
            
            # ...
    );

Register method. These method is called directly from L<DBIx::Custom::Model> object.

    $model->update_or_insert;
    $model->find_or_create;

=head2 C<mycolumn>

    my $column = $self->mycolumn;
    my $column = $self->mycolumn(book => ['author', 'title']);
    my $column = $self->mycolumn(['author', 'title']);

Create column clause for myself. The follwoing column clause is created.

    book.author as author,
    book.title as title

If table name is ommited, C<table> attribute of the model is used.
If column names is omitted, C<columns> attribute of the model is used.

=head2 C<new>

    my $table = DBIx::Custom::Table->new;

Create a L<DBIx::Custom::Table> object.

=head2 C<select>

    $table->select(...);
    
Same as C<select> of L<DBIx::Custom> except that
you don't have to specify C<table> option.

=head2 C<update>

    $table->update(...);
    
Same as C<update> of L<DBIx::Custom> except that
you don't have to specify C<table> option.

=head2 C<update_all>

    $table->update_all(param => \%param);
    
Same as C<update_all> of L<DBIx::Custom> except that
you don't have to specify table name.

=cut
