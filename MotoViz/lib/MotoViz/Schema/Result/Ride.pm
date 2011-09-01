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

=head2 time_start

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 time_end

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 lat_start

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lon_start

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lat_end

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lon_end

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lat_min

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lon_min

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lat_max

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lon_max

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 total_gps_distance

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 total_sensor_distance

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
  "time_start",
  {
    data_type => "datetime",
    "datetime_undef_if_invalid" => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "time_end",
  {
    data_type => "datetime",
    "datetime_undef_if_invalid" => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "lat_start",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lon_start",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lat_end",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lon_end",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lat_min",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lon_min",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lat_max",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lon_max",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "total_gps_distance",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "total_sensor_distance",
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


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-09-01 10:39:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F/OEYHwx0wslcTuVGqCwbw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
