package MotoViz::Schema::Result::Point;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

MotoViz::Schema::Result::Point

=cut

__PACKAGE__->table("points");

=head1 ACCESSORS

=head2 point_id

  data_type: 'bigint'
  is_nullable: 0

=head2 ride_id

  data_type: 'varchar'
  default_value: (empty string)
  is_foreign_key: 1
  is_nullable: 0
  size: 40

=head2 point_num

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 lat

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 lon

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 alt

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 time

  data_type: 'double precision'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 time_diff

  data_type: 'mediumint'
  default_value: -1
  is_nullable: 0

=head2 num_sats

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 bearing

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 speed_gps

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 speed_sensor

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 distance_gps_total

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 distance_gps_delta

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 distance_sensor_total

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 distance_sensor_delta

  data_type: 'double precision'
  default_value: 0
  is_nullable: 0

=head2 raw_data

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 battery_volts

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 battery_amps

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 battery_watt_hours

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 battery_amp_hours

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 motor_temp_kelly

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 motor_temp_sensor

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 motor_volts

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 motor_amps

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 throttle_percent

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "point_id",
  { data_type => "bigint", is_nullable => 0 },
  "ride_id",
  {
    data_type => "varchar",
    default_value => "",
    is_foreign_key => 1,
    is_nullable => 0,
    size => 40,
  },
  "point_num",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "lat",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "lon",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "alt",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "time",
  {
    data_type => "double precision",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "time_diff",
  { data_type => "mediumint", default_value => -1, is_nullable => 0 },
  "num_sats",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "bearing",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "speed_gps",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "speed_sensor",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "distance_gps_total",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "distance_gps_delta",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "distance_sensor_total",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "distance_sensor_delta",
  { data_type => "double precision", default_value => 0, is_nullable => 0 },
  "raw_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "battery_volts",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "battery_amps",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "battery_watt_hours",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "battery_amp_hours",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "motor_temp_kelly",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "motor_temp_sensor",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "motor_volts",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "motor_amps",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "throttle_percent",
  { data_type => "float", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("point_id");

=head1 RELATIONS

=head2 ride

Type: belongs_to

Related object: L<MotoViz::Schema::Result::Ride>

=cut

__PACKAGE__->belongs_to(
  "ride",
  "MotoViz::Schema::Result::Ride",
  { ride_id => "ride_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-09-01 21:42:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0xsVn9NFzQA7XQGkw9ZA6Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
