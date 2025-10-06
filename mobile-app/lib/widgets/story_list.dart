import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'common/presigned_image.dart';

class StoryList extends StatelessWidget {
  const StoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 10, // Replace with actual story count
        itemBuilder: (context, index) {
          return _buildStoryItem(context, index);
        },
      ),
    );
  }

  Widget _buildStoryItem(BuildContext context, int index) {
    final isAddStory = index == 0;

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          // Story Circle
          GestureDetector(
            onTap: () {
              if (isAddStory) {
                // Handle add story
              } else {
                // Handle view story
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAddStory
                      ? Colors.grey[400]!
                      : Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                gradient: isAddStory
                    ? null
                    : LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: isAddStory
                    ? Icon(Icons.add, color: Colors.grey[600], size: 24)
                    : ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: 'https://picsum.photos/60/60?random=$index',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Story Label
          Text(
            isAddStory ? 'Your Story' : 'User $index',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
