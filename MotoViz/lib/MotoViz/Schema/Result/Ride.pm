package MotoViz::Schema::Result::Ride;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

MotoViz::Schema::Result::Ride

=cut

__PACKAGE__->table("rides");

=head1 ACCESSORS

=head2 ride_id

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 40

=head2 user_id

  data_type: 'varchar'
  default_value: (empty string)
  is_foreign_key: 1
  is_nullable: 0
  size: 40

=head2 created

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 start_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 end_time

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 start_lat

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 start_lon

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 end_lat

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 end_lon

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 min_lat

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 min_lon

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 max_lat

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 max_lon

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 distance

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 wh_total

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 wh_per_mile

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 max_speed

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 avg_speed

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 num_points

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 raw_data_type

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 40

=cut

__PACKAGE__->add_columns(
  "ride_id",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "user_id",
  {
    data_type => "varchar",
    default_value => "",
    is_foreign_key => 1,
    is_nullable => 0,
    size => 40,
  },
  "created",
  {
    data_type => "timestamp",
    "datetime_undef_if_invalid" => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "start_time",
  {
    data_type => "datetime",
    "datetime_undef_if_invalid" => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "end_time",
  {
    data_type => "datetime",
    "datetime_undef_if_invalid" => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "start_lat",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "start_lon",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "end_lat",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "end_lon",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "min_lat",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "min_lon",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "max_lat",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "max_lon",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "distance",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "wh_total",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "wh_per_mile",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "max_speed",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "avg_speed",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "num_points",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "raw_data_type",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
);
__PACKAGE__->set_primary_key("ride_id");

=head1 RELATIONS

=head2 points

Type: has_many

Related object: L<MotoViz::Schema::Result::Point>

=cut

__PACKAGE__->has_many(
  "points",
  "MotoViz::Schema::Result::Point",
  { "foreign.ride_id" => "self.ride_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<MotoViz::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "MotoViz::Schema::Result::User",
  { user_id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-08-31 13:45:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jZcL8PSJ7wUxP/QsZYAsyA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
