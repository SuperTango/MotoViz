package MotoViz::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

MotoViz::Schema::Result::User

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 user_id

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 40

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 60

=head2 pass

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 60

=head2 email

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 timezone

  data_type: 'varchar'
  is_nullable: 1
  size: 8

=head2 timezone_name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 60 },
  "pass",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 60 },
  "email",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 64 },
  "timezone",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "timezone_name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("user_id");
__PACKAGE__->add_unique_constraint("email", ["email"]);

=head1 RELATIONS

=head2 rides

Type: has_many

Related object: L<MotoViz::Schema::Result::Ride>

=cut

__PACKAGE__->has_many(
  "rides",
  "MotoViz::Schema::Result::Ride",
  { "foreign.user_id" => "self.user_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-09-02 08:56:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ygIjYwlTC9sw748ph3USfw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
