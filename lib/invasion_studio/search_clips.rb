# frozen_string_literal: true

module InvasionStudio
  # Translates library search/filter/sort parameters into database queries.
  # Returns clip hashes in the same shape as ClipRepository.
  class SearchClips
    STATES = %w[everything unassigned assigned deleted].freeze
    DEFAULT_STATE = 'everything'

    def initialize(database, clip_repository:)
      @database = database
      @clip_repository = clip_repository
    end

    def call(query: nil, tag: nil, min_rating: nil, result: nil, state: nil, sort: nil)
      dataset = @database[:clips]
      dataset = apply_state(dataset, presence(state))
      dataset = apply_query(dataset, presence(query))
      dataset = apply_tag(dataset, presence(tag))
      dataset = apply_min_rating(dataset, presence(min_rating))
      dataset = apply_result(dataset, presence(result))
      dataset = apply_sort(dataset, presence(sort))
      dataset.select(:id).map { |record| @clip_repository.find(record[:id]) }
    end

    private

    def presence(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def apply_state(dataset, state)
      case state
      when 'deleted'
        dataset.exclude(deleted_at: nil)
      when 'unassigned'
        dataset.where(deleted_at: nil).exclude(id: assigned_clip_ids)
      when 'assigned'
        dataset.where(deleted_at: nil).where(id: assigned_clip_ids)
      else
        dataset.where(deleted_at: nil)
      end
    end

    def apply_query(dataset, query)
      return dataset unless query

      term = "%#{query}%"
      dataset.where(
        Sequel.ilike(:title, term) |
        Sequel.ilike(:note, term) |
        Sequel.ilike(:original_filename, term)
      )
    end

    def apply_tag(dataset, tag)
      return dataset unless tag

      tag_ids = @database[:tags].where(name: tag.downcase).select(:id)
      dataset.where(id: @database[:clip_tags].where(tag_id: tag_ids).select(:clip_id))
    end

    def apply_min_rating(dataset, min_rating)
      return dataset unless min_rating

      dataset.where { rating >= min_rating.to_i }
    end

    def apply_result(dataset, result)
      return dataset unless result

      dataset.where(result: result)
    end

    def apply_sort(dataset, sort)
      case sort
      when 'newest'
        dataset.order(Sequel.desc(:created_at), Sequel.desc(:id))
      when 'rating-desc'
        dataset.order(Sequel.desc(:rating), :created_at, :id)
      when 'rating-asc'
        dataset.order(:rating, :created_at, :id)
      when 'title'
        dataset.order(Sequel.function(:lower, Sequel.function(:coalesce, :title, :original_filename)), :id)
      when 'duration-desc'
        dataset.order(Sequel.desc(:duration, nulls: :last), :created_at, :id)
      when 'duration-asc'
        dataset.order(Sequel.asc(:duration, nulls: :last), :created_at, :id)
      else
        # 'oldest' and the default project order are both creation order
        dataset.order(:created_at, :id)
      end
    end

    def assigned_clip_ids
      @database[:compilation_clips].select(:clip_id)
    end
  end
end
