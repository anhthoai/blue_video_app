import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding...');

  // Clear existing data
  console.log('🧹 Clearing existing data...');
  await prisma.chatMessage.deleteMany();
  await prisma.chatRoomParticipant.deleteMany();
  await prisma.chatRoom.deleteMany();
  await prisma.like.deleteMany();
  await prisma.comment.deleteMany();
  await prisma.follow.deleteMany();
  await prisma.communityPost.deleteMany();
  await prisma.video.deleteMany();
  await prisma.user.deleteMany();

  // Create sample users
  console.log('👥 Creating sample users...');
  
  // First user - Admin account
  const adminUser = await prisma.user.create({
    data: {
      username: 'admin',
      email: 'admin@example.com',
      passwordHash: await bcrypt.hash('123456', 10),
      firstName: 'Admin',
      lastName: 'User',
      bio: 'Platform administrator',
      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
      isVerified: true,
      isActive: true,
      role: 'ADMIN',
    },
  });
  
  console.log('✅ Created admin user: admin@example.com / 123456');
  
  const users = await Promise.all([
    Promise.resolve(adminUser), // Include admin in users array
    prisma.user.create({
      data: {
        username: 'alex_creator',
        email: 'alex@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'Alex',
        lastName: 'Johnson',
        bio: 'Content creator and tech enthusiast. Love sharing knowledge about programming and digital creativity!',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        isVerified: true,
        isActive: true,
      },
    }),
    prisma.user.create({
      data: {
        username: 'sarah_vlogger',
        email: 'sarah@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'Sarah',
        lastName: 'Chen',
        bio: 'Lifestyle vlogger | Travel enthusiast | Coffee addict ☕',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
        isVerified: true,
        isActive: true,
      },
    }),
    prisma.user.create({
      data: {
        username: 'mike_gamer',
        email: 'mike@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'Mike',
        lastName: 'Rodriguez',
        bio: 'Gaming content creator | Streamer | Esports enthusiast',
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        isVerified: false,
        isActive: true,
      },
    }),
    prisma.user.create({
      data: {
        username: 'emma_artist',
        email: 'emma@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'Emma',
        lastName: 'Wilson',
        bio: 'Digital artist | Illustrator | Creative soul 🎨',
        avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        isVerified: true,
        isActive: true,
      },
    }),
    prisma.user.create({
      data: {
        username: 'david_tech',
        email: 'david@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'David',
        lastName: 'Kim',
        bio: 'Tech reviewer | Gadget enthusiast | Early adopter',
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
        isVerified: true,
        isActive: true,
      },
    }),
    prisma.user.create({
      data: {
        username: 'lisa_fitness',
        email: 'lisa@example.com',
        passwordHash: await bcrypt.hash('password123', 10),
        firstName: 'Lisa',
        lastName: 'Brown',
        bio: 'Fitness coach | Nutrition expert | Wellness advocate 💪',
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face',
        isVerified: false,
        isActive: true,
      },
    }),
  ]);

  console.log(`✅ Created ${users.length} users`);

  // Create follow relationships
  console.log('👥 Creating follow relationships...');
  const followRelations = [
    { followerId: users[1].id, followingId: users[0].id }, // Sarah follows Alex
    { followerId: users[2].id, followingId: users[0].id }, // Mike follows Alex
    { followerId: users[3].id, followingId: users[0].id }, // Emma follows Alex
    { followerId: users[4].id, followingId: users[0].id }, // David follows Alex
    { followerId: users[5].id, followingId: users[0].id }, // Lisa follows Alex
    { followerId: users[0].id, followingId: users[1].id }, // Alex follows Sarah
    { followerId: users[2].id, followingId: users[1].id }, // Mike follows Sarah
    { followerId: users[3].id, followingId: users[1].id }, // Emma follows Sarah
    { followerId: users[0].id, followingId: users[2].id }, // Alex follows Mike
    { followerId: users[1].id, followingId: users[2].id }, // Sarah follows Mike
    { followerId: users[0].id, followingId: users[3].id }, // Alex follows Emma
    { followerId: users[1].id, followingId: users[3].id }, // Sarah follows Emma
    { followerId: users[0].id, followingId: users[4].id }, // Alex follows David
    { followerId: users[1].id, followingId: users[4].id }, // Sarah follows David
    { followerId: users[0].id, followingId: users[5].id }, // Alex follows Lisa
  ];

  await Promise.all(
    followRelations.map(relation =>
      prisma.follow.create({
        data: relation,
      })
    )
  );

  console.log(`✅ Created ${followRelations.length} follow relationships`);

  // Create sample videos
  console.log('🎥 Creating sample videos...');
  // Sample videos using Google sample videos
  const sampleVideos = [
    {
      title: 'Big Buck Bunny',
      description: 'Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself. When one sunny day three rodents rudely harass him, something snaps... and the rabbit ain\'t no bunny anymore! In the typical cartoon tradition he prepares the nasty rodents a comical revenge.\n\nLicensed under the Creative Commons Attribution license\nhttp://www.bigbuckbunny.org',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
      duration: 596, // ~10 minutes
      views: 15420,
      likes: 892,
      comments: 3,
      shares: 0,
    },
    {
      title: 'Elephant Dream',
      description: 'The first Blender Open Movie from 2006',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg',
      duration: 653, // ~11 minutes
      views: 8930,
      likes: 456,
      comments: 1,
      shares: 0,
    },
    {
      title: 'For Bigger Blazes',
      description: 'HBO GO now works with Chromecast -- the easiest way to enjoy online video on your TV. For when you want to settle into your Iron Throne to watch the latest episodes. For $35.\nLearn how to use Chromecast with HBO GO and more at google.com/chromecast.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
      duration: 15, // 15 seconds
      views: 25670,
      likes: 1234,
      comments: 0,
      shares: 0,
    },
    {
      title: 'For Bigger Escape',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV—for when Batman\'s escapes aren\'t quite big enough. For $35. Learn how to use Chromecast with Google Play Movies and more at google.com/chromecast.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
      duration: 15, // 15 seconds
      views: 12340,
      likes: 678,
      comments: 0,
      shares: 0,
    },
    {
      title: 'For Bigger Fun',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV. For $35.  Find out more at google.com/chromecast.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerFun.jpg',
      duration: 15, // 15 seconds
      views: 9870,
      likes: 345,
      comments: 0,
      shares: 0,
    },
    {
      title: 'For Bigger Joyrides',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV—for the times that call for bigger joyrides. For $35. Learn how to use Chromecast with YouTube and more at google.com/chromecast.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
      duration: 15, // 15 seconds
      views: 18750,
      likes: 567,
      comments: 0,
      shares: 0,
    },
    {
      title: 'For Bigger Meltdowns',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV—for when you want to make Buster\'s big meltdowns even bigger. For $35. Learn how to use Chromecast with Netflix and more at google.com/chromecast.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerMeltdowns.jpg',
      duration: 15, // 15 seconds
      views: 11200,
      likes: 445,
      comments: 0,
      shares: 0,
    },
    {
      title: 'Sintel',
      description: 'Sintel is an independently produced short film, initiated by the Blender Foundation as a means to further improve and validate the free/open source 3D creation suite Blender. With initial funding provided by 1000s of donations via the internet community, it has again proven to be a viable development model for both open 3D technology as for independent animation film.\nThis 15 minute film has been realized in the studio of the Amsterdam Blender Institute, by an international team of artists and developers. In addition to that, several crucial technical and creative targets have been realized online, by developers and artists and teams all over the world.\nwww.sintel.org',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/Sintel.jpg',
      duration: 888, // ~15 minutes
      views: 22300,
      likes: 1234,
      comments: 3,
      shares: 0,
    },
    {
      title: 'Subaru Outback On Street And Dirt',
      description: 'Smoking Tire takes the all-new Subaru Outback to the highest point we can find in hopes our customer-appreciation Balloon Launch will get some free T-shirts into the hands of our viewers.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/SubaruOutbackOnStreetAndDirt.jpg',
      duration: 662, // ~11 minutes
      views: 15600,
      likes: 789,
      comments: 0,
      shares: 0,
    },
    {
      title: 'Tears of Steel',
      description: 'Tears of Steel was realized with crowd-funding by users of the open source 3D creation tool Blender. Target was to improve and test a complete open and free pipeline for visual effects in film - and to make a compelling sci-fi film in Amsterdam, the Netherlands.  The film itself, and all raw material used for making it, have been released under the Creatieve Commons 3.0 Attribution license. Visit the tearsofsteel.org website to find out more about this, or to purchase the 4-DVD box with a lot of extras.  (CC) Blender Foundation - http://www.tearsofsteel.org',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg',
      duration: 734, // ~12 minutes
      views: 19800,
      likes: 945,
      comments: 0,
      shares: 0,
    },
    {
      title: 'Volkswagen GTI Review',
      description: 'The Smoking Tire heads out to Adams Motorsports Park in Riverside, CA to test the most requested car of 2010, the Volkswagen GTI. Will it beat the Mazdaspeed3\'s standard-setting lap time? Watch and see...',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/VolkswagenGTIReview.jpg',
      duration: 364, // ~6 minutes
      views: 13400,
      likes: 623,
      comments: 2,
      shares: 0,
    },
    {
      title: 'We Are Going On Bullrun',
      description: 'The Smoking Tire is going on the 2010 Bullrun Live Rally in a 2011 Shelby GT500, and posting a video from the road every single day! The only place to watch them is by subscribing to The Smoking Tire or watching at BlackMagicShine.com',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/WeAreGoingOnBullrun.jpg',
      duration: 105, // ~2 minutes
      views: 8900,
      likes: 412,
      comments: 0,
      shares: 0,
    },
    {
      title: 'What care can you get for a grand?',
      description: 'The Smoking Tire meets up with Chris and Jorge from CarsForAGrand.com to see just how far $1,000 can go when looking for a car.The Smoking Tire meets up with Chris and Jorge from CarsForAGrand.com to see just how far $1,000 can go when looking for a car.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4',
      thumbnailUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/WhatCarCanYouGetForAGrand.jpg',
      duration: 304, // ~5 minutes
      views: 16700,
      likes: 756,
      comments: 0,
      shares: 0,
    },
  ];

  const videos = await Promise.all(
    sampleVideos.map((videoData, index) =>
      prisma.video.create({
        data: {
          userId: users[index % users.length]!.id, // Distribute videos among users
          title: videoData.title,
          description: videoData.description,
          videoUrl: videoData.videoUrl,
          thumbnailUrl: videoData.thumbnailUrl,
          duration: videoData.duration,
          fileSize: BigInt(Math.floor(Math.random() * 100000000) + 10000000), // Random file size
          quality: '1080p',
          views: videoData.views,
          likes: videoData.likes,
          comments: videoData.comments,
          shares: videoData.shares,
          isPublic: true,
        },
      })
    )
  );

  console.log(`✅ Created ${videos.length} videos`);

  // Create sample community posts
  console.log('📝 Creating sample community posts...');
  const posts = await Promise.all([
    prisma.communityPost.create({
      data: {
        userId: users[0].id,
        title: 'Just finished my latest coding project!',
        content: 'Built a full-stack web application using React, Node.js, and PostgreSQL. The learning curve was steep but totally worth it! 🚀',
        type: 'TEXT',
        images: [],
        videos: [],
        tags: ['coding', 'web-development', 'react', 'nodejs'],
        category: 'Technology',
        likes: 45,
        comments: 12,
        shares: 8,
        views: 234,
        isPublic: true,
      },
    }),
    prisma.communityPost.create({
      data: {
        userId: users[1].id,
        title: 'Beautiful sunset from my balcony 🌅',
        content: 'Sometimes the best moments are the simple ones. Grateful for this peaceful evening.',
        type: 'MEDIA',
        images: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop',
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&h=600&fit=crop',
        ],
        videos: [
          'https://example.com/videos/sunset-timelapse.mp4',
        ],
        tags: ['sunset', 'nature', 'photography', 'peaceful'],
        category: 'Lifestyle',
        likes: 78,
        comments: 23,
        shares: 15,
        views: 456,
        isPublic: true,
      },
    }),
    prisma.communityPost.create({
      data: {
        userId: users[2].id,
        title: 'Check out this amazing gaming setup!',
        content: 'Finally completed my dream gaming setup. RGB lights, mechanical keyboard, and a 4K monitor. Ready for some serious gaming sessions!',
        type: 'MEDIA',
        images: [
          'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&h=600&fit=crop',
        ],
        videos: [],
        tags: ['gaming', 'setup', 'rgb', 'gaming-chair'],
        category: 'Gaming',
        likes: 123,
        comments: 34,
        shares: 28,
        views: 789,
        isPublic: true,
      },
    }),
    prisma.communityPost.create({
      data: {
        userId: users[3].id,
        title: 'New digital art piece - Fantasy Landscape',
        content: 'Spent 3 days working on this fantasy landscape. The details in the mountains and the magical atmosphere took forever to get right!',
        type: 'MEDIA',
        images: [
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=600&fit=crop',
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=600&fit=crop',
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800&h=600&fit=crop',
        ],
        videos: [],
        tags: ['digital-art', 'fantasy', 'landscape', 'artwork'],
        category: 'Art',
        likes: 156,
        comments: 45,
        shares: 32,
        views: 892,
        isPublic: true,
      },
    }),
    prisma.communityPost.create({
      data: {
        userId: users[4].id,
        title: 'Latest tech review is up!',
        content: 'Just published my review of the new MacBook Pro M3. The performance improvements are incredible!',
        type: 'LINK',
        images: [],
        videos: [],
        linkUrl: 'https://example.com/macbook-pro-review',
        linkTitle: 'MacBook Pro M3 Review - Performance Beast',
        linkDescription: 'Comprehensive review of Apple\'s latest MacBook Pro with M3 chip, including benchmarks and real-world usage.',
        tags: ['tech-review', 'macbook', 'apple', 'performance'],
        category: 'Technology',
        likes: 89,
        comments: 23,
        shares: 18,
        views: 567,
        isPublic: true,
      },
    }),
    prisma.communityPost.create({
      data: {
        userId: users[5].id,
        title: 'What\'s your favorite workout routine?',
        content: 'I\'m looking to switch up my fitness routine. What workouts do you find most effective?',
        type: 'POLL',
        images: [],
        videos: [],
        pollOptions: {
          options: [
            'Weight Training',
            'Cardio',
            'Yoga',
            'HIIT',
            'Swimming',
          ],
        },
        pollVotes: {
          votes: {
            'Weight Training': 45,
            'Cardio': 32,
            'Yoga': 28,
            'HIIT': 38,
            'Swimming': 15,
          },
        },
        tags: ['fitness', 'workout', 'poll', 'health'],
        category: 'Fitness',
        likes: 67,
        comments: 89,
        shares: 12,
        views: 445,
        isPublic: true,
      },
    }),
  ]);

  console.log(`✅ Created ${posts.length} community posts`);

  // Create sample comments
  console.log('💬 Creating sample comments...');
  const comments = await Promise.all([
    // Comments on videos
    prisma.comment.create({
      data: {
        userId: users[1].id,
        contentId: videos[0]!.id,
        contentType: 'VIDEO',
        content: 'Great tutorial! Really helped me understand React hooks better.',
        likes: 12,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[2].id,
        contentId: videos[0]!.id,
        contentType: 'VIDEO',
        content: 'Thanks for sharing! Can you make a follow-up video on state management?',
        likes: 8,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[3].id,
        contentId: videos[1]!.id,
        contentType: 'VIDEO',
        content: 'Love this Blender animation! The story is beautiful.',
        likes: 15,
      },
    }),
    // More comments on various videos
    prisma.comment.create({
      data: {
        userId: users[0].id,
        contentId: videos[7]!.id, // Sintel
        contentType: 'VIDEO',
        content: 'Absolutely stunning animation! The Blender Foundation does amazing work.',
        likes: 45,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[1].id,
        contentId: videos[7]!.id, // Sintel
        contentType: 'VIDEO',
        content: 'This is one of my favorite short films. The story is so emotional!',
        likes: 32,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[2].id,
        contentId: videos[7]!.id, // Sintel
        contentType: 'VIDEO',
        content: 'The quality of the animation is incredible for an open source project.',
        likes: 28,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[3].id,
        contentId: videos[10]!.id, // Volkswagen GTI Review
        contentType: 'VIDEO',
        content: 'Great review! Really helpful for my car buying decision.',
        likes: 18,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[4].id,
        contentId: videos[10]!.id, // Volkswagen GTI Review
        contentType: 'VIDEO',
        content: 'The GTI is such a fun car. Thanks for the detailed review!',
        likes: 12,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[5].id,
        contentId: videos[0]!.id, // Big Buck Bunny
        contentType: 'VIDEO',
        content: 'Classic! I love this animation.',
        likes: 22,
      },
    }),
    // Comments on posts
    prisma.comment.create({
      data: {
        userId: users[1].id,
        contentId: posts[0].id,
        contentType: 'POST',
        content: 'Amazing work! What tech stack did you use?',
        likes: 6,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[2].id,
        contentId: posts[0].id,
        contentType: 'POST',
        content: 'This is so inspiring! I\'m just starting to learn web development.',
        likes: 4,
      },
    }),
    prisma.comment.create({
      data: {
        userId: users[4].id,
        contentId: posts[1].id,
        contentType: 'POST',
        content: 'Beautiful sunset! The colors are amazing.',
        likes: 9,
      },
    }),
  ]);

  console.log(`✅ Created ${comments.length} comments`);

  // Create sample likes
  console.log('👍 Creating sample likes...');
  const likes = await Promise.all([
    // Likes on videos
    ...videos.slice(0, 3).map(video =>
      prisma.like.create({
        data: {
          userId: users[1].id,
          contentId: video.id,
          contentType: 'VIDEO',
          type: 'LIKE',
        },
      })
    ),
    ...videos.slice(1, 4).map(video =>
      prisma.like.create({
        data: {
          userId: users[2].id,
          contentId: video.id,
          contentType: 'VIDEO',
          type: 'LIKE',
        },
      })
    ),
    // Likes on posts
    ...posts.slice(0, 3).map(post =>
      prisma.like.create({
        data: {
          userId: users[0].id,
          contentId: post.id,
          contentType: 'POST',
          type: 'LIKE',
        },
      })
    ),
    ...posts.slice(1, 4).map(post =>
      prisma.like.create({
        data: {
          userId: users[1].id,
          contentId: post.id,
          contentType: 'POST',
          type: 'LIKE',
        },
      })
    ),
    // Likes on comments
    ...comments.slice(0, 3).map(comment =>
      prisma.like.create({
        data: {
          userId: users[0].id,
          contentId: comment.id,
          contentType: 'COMMENT',
          type: 'LIKE',
        },
      })
    ),
  ]);

  console.log(`✅ Created ${likes.length} likes`);

  // Create sample chat rooms
  console.log('💬 Creating sample chat rooms...');
  const chatRooms = await Promise.all([
    prisma.chatRoom.create({
      data: {
        name: 'Tech Discussion',
        type: 'GROUP',
        createdBy: users[0].id,
      },
    }),
    prisma.chatRoom.create({
      data: {
        name: 'Gaming Squad',
        type: 'GROUP',
        createdBy: users[2].id,
      },
    }),
    prisma.chatRoom.create({
      data: {
        name: null, // Private chat
        type: 'PRIVATE',
        createdBy: users[0].id,
      },
    }),
  ]);

  // Add participants to chat rooms
  console.log('👥 Adding chat room participants...');
  const participants = await Promise.all([
    // Tech Discussion group
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[0].id,
      },
    }),
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[1].id,
      },
    }),
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[4].id,
      },
    }),
    // Gaming Squad group
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[2].id,
      },
    }),
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[0].id,
      },
    }),
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[1].id,
      },
    }),
    // Private chat
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[2].id,
        userId: users[0].id,
      },
    }),
    prisma.chatRoomParticipant.create({
      data: {
        roomId: chatRooms[2].id,
        userId: users[1].id,
      },
    }),
  ]);

  console.log(`✅ Created ${chatRooms.length} chat rooms with ${participants.length} participants`);

  // Create sample chat messages
  console.log('💬 Creating sample chat messages...');
  const chatMessages = await Promise.all([
    // Tech Discussion messages
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[0].id,
        content: 'Hey everyone! Just finished my React tutorial. What do you think?',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[1].id,
        content: 'Great work Alex! The explanation was really clear.',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[0].id,
        userId: users[4].id,
        content: 'I learned a lot from it. Thanks for sharing!',
        messageType: 'TEXT',
      },
    }),
    // Gaming Squad messages
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[2].id,
        content: 'Anyone up for some gaming tonight?',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[0].id,
        content: 'I\'m in! What game are we playing?',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[1].id,
        userId: users[1].id,
        content: 'Count me in too! 🎮',
        messageType: 'TEXT',
      },
    }),
    // Private chat messages
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[2].id,
        userId: users[0].id,
        content: 'Hey Sarah! How\'s your vlogging going?',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[2].id,
        userId: users[1].id,
        content: 'It\'s going great! Just posted a new video about morning routines.',
        messageType: 'TEXT',
      },
    }),
    prisma.chatMessage.create({
      data: {
        roomId: chatRooms[2].id,
        userId: users[0].id,
        content: 'Awesome! I\'ll check it out.',
        messageType: 'TEXT',
      },
    }),
  ]);

  console.log(`✅ Created ${chatMessages.length} chat messages`);

  console.log('🎉 Database seeding completed successfully!');
  console.log('\n📊 Summary:');
  console.log(`👥 Users: ${users.length}`);
  console.log(`👥 Follows: ${followRelations.length}`);
  console.log(`🎥 Videos: ${videos.length}`);
  console.log(`📝 Posts: ${posts.length}`);
  console.log(`💬 Comments: ${comments.length}`);
  console.log(`👍 Likes: ${likes.length}`);
  console.log(`💬 Chat Rooms: ${chatRooms.length}`);
  console.log(`👥 Chat Participants: ${participants.length}`);
  console.log(`💬 Chat Messages: ${chatMessages.length}`);
}

main()
  .catch((e) => {
    console.error('❌ Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
