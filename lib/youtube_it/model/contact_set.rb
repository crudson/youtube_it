class YouTubeIt
  module Model
    class ContactSet < Array
      attr_accessor :updated_at
      attr_accessor :total_result_count

      def inspect
        "@updated_at=#{@updated_at}, @total_result_count=#{@total_result_count}, items=#{super}"
      end
    end
  end
end
