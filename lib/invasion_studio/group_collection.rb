# frozen_string_literal: true

module InvasionStudio
  class GroupCollection
    attr_reader :groups

    def initialize(groups, clip_lookup:)
      @groups = groups
      @clip_lookup = clip_lookup
    end

    def create(name)
      return false if find(name)

      @groups << { 'name' => name, 'clip_ids' => [] }
      true
    end

    def rename(old_name, new_name)
      return false if old_name == new_name || find(new_name)

      group = find(old_name)
      return false unless group

      group['name'] = new_name
      true
    end

    def delete(name)
      !!@groups.reject! { |group| group['name'] == name }
    end

    def add_clip(group_name, clip_id)
      group = find(group_name)
      return false unless group && @clip_lookup.call(clip_id)

      group['clip_ids'] << clip_id unless group['clip_ids'].include?(clip_id)
      true
    end

    def remove_clip(group_name, clip_id)
      group = find(group_name)
      return false unless group

      group['clip_ids'].delete(clip_id)
      true
    end

    def reorder(group_name, old_index, new_index)
      group = find(group_name)
      return false unless group

      clip_ids = group['clip_ids']
      return false unless valid_index?(old_index, clip_ids) && valid_index?(new_index, clip_ids)

      clip_ids.insert(new_index, clip_ids.delete_at(old_index))
      true
    end

    def clips(group_name)
      group = find(group_name)
      return [] unless group

      group['clip_ids'].filter_map { |id| @clip_lookup.call(id) }.reject { |clip| clip['deleted'] }
    end

    def names_for_clip(clip_id)
      @groups.select { |group| group['clip_ids'].include?(clip_id) }.map { |group| group['name'] }
    end

    def prune(valid_ids)
      @groups.each { |group| group['clip_ids'] &= valid_ids }
    end

    private

    def find(name)
      @groups.find { |group| group['name'] == name }
    end

    def valid_index?(index, items)
      index.is_a?(Integer) && index >= 0 && index < items.length
    end
  end
end
