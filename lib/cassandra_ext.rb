# Extensions/bugfixes to fauna/cassandra
class Cassandra

  # Fix interface incompatibility due to new Thrift interface in Cassandra
  # 0.7.x
  def _count_columns(column_family, key, super_column, consistency)
    parent = CassandraThrift::ColumnParent.new(
      :column_family => column_family,
      :super_column => super_column
    )
    range = CassandraThrift::SliceRange.new(
      :start => '',
      :finish => '',
      :reversed => false
    )
    predicate = CassandraThrift::SlicePredicate.new(:slice_range => range)

    client.get_count(key, parent, predicate, consistency)
  end

end
