import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social/layout/cubit/social_state.dart';
import 'package:social/models/message_model.dart';
import 'package:social/models/post_model.dart';
import 'package:social/models/user_model.dart';
import 'package:social/modules/add_post.dart';
import 'package:social/modules/chat_items_screen.dart';
import 'package:social/modules/feeds_screen.dart';
import 'package:social/modules/settings_screen.dart';
import 'package:social/shared/components/constants.dart';
import 'package:social/shared/styles/icon_broken.dart';

class SocialCubit extends Cubit<SocialState> {
  SocialCubit() : super(SocialInitial());

  static SocialCubit get(context) => BlocProvider.of(context);

  int currentIndex = 0;
  List<BottomNavigationBarItem> items = [
    const BottomNavigationBarItem(icon: Icon(IconBroken.Home), label: "Home"),
    const BottomNavigationBarItem(icon: Icon(IconBroken.Chat), label: "Chats"),
    const BottomNavigationBarItem(
        icon: Icon(IconBroken.Paper_Upload), label: "Post"),
    const BottomNavigationBarItem(
        icon: Icon(IconBroken.Setting), label: "Settings"),
  ];

  void changeIndex(int index) {
    if (index == 2) {
      emit(SocialChangeIndexUploadPost());
    } else if (index == 1) {
      getAllUsers();
      currentIndex = index;
    } else {
      currentIndex = index;
    }
    emit(SocialChangeIndex());
  }

  File? profileImage;
  var picker = ImagePicker();

  Future<void> getProfileImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      profileImage = File(pickedFile.path);
      emit(SocialGetProfileImageSuccess());
    } else {
      debugPrint('No image selected');
      emit(SocialGetProfileImageError());
    }
  }

  File? coverImage;

  Future<void> getCoverImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      coverImage = File(pickedFile.path);
      emit(SocialGetCoverImageSuccess());
    } else {
      debugPrint('No image selected');
      emit(SocialGetCoverImageError());
    }
  }

  List<Widget> pages = [
    const FeedsScreen(),
    const ChatItemsScreen(),
    AddPost(),
    const SettingsScreen(),
  ];
  List<String> appBarTexts = [
    "Home",
    "Chat",
    "Add Post",
    "Posts",
    "Setting",
  ];

  UserModel? userModel;

  Future<void> getUserData() async {
    emit(SocialGetUserDataLoading());
    final snapShot =
        await FirebaseFirestore.instance.collection('users').doc(token).get();
    try {
      userModel = UserModel.fromJson(snapShot.data()!);
      emit(SocialGetUserDataSuccess());
    } catch (e) {
      emit(SocialGetUserDataError());
    }
  }

  void updateUserData({
    required String? name,
    required String? bio,
    required String? phone,
    required String? password,
    String? profile,
    String? cover,
  }) {
    emit(SocialUpdateUserDataLoading());
    UserModel updateUserModel = UserModel(
      name: name,
      phone: phone,
      bio: bio,
      uId: userModel!.uId,
      email: userModel!.email,
      password: password,
      image: profile ?? userModel!.image,
      cover: cover ?? userModel!.cover,
      isEmailVerified: false,
    );
    FirebaseFirestore.instance
        .collection('users')
        .doc(userModel!.uId)
        .update(updateUserModel.toMap())
        .then(
      (onValue) {
        getUserData();
      },
    ).catchError(
      (onError) {
        print(onError.toString());
        emit(SocialUpdateUserDataError());
      },
    );
  }

  void uploadProfileImage({
    required String? name,
    required String? bio,
    required String? phone,
    required String? password,
  }) {
    emit(SocialUploadProfileImageLoading());
    // save the image with the last path segment
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child('users/${Uri.file(profileImage!.path).pathSegments.last}')
        .putFile(profileImage!)
        .then(
      (onValue) {
        emit(SocialUploadProfileImageSuccess());
        onValue.ref.getDownloadURL().then((onValue) {
          updateUserData(
            name: name,
            bio: bio,
            phone: phone,
            password: password,
            profile: onValue,
          );
        }).catchError((onError) {
          emit(SocialUploadProfileImageError());
        });
      },
    ).catchError(
      (onError) {
        emit(SocialUploadProfileImageError());
      },
    );
  }

  void uploadCoverImage({
    required String? name,
    required String? bio,
    required String? phone,
    required String? password,
  }) {
    emit(SocialUploadCoverImageLoading());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child('users/${Uri.file(coverImage!.path).pathSegments.last}')
        .putFile(coverImage!)
        .then(
      (onValue) {
        emit(SocialUploadCoverImageSuccess());
        onValue.ref.getDownloadURL().then((onValue) {
          updateUserData(
            name: name,
            bio: bio,
            phone: phone,
            password: password,
            cover: onValue,
          );
        }).catchError((onError) {
          emit(SocialUploadCoverImageError());
        });
      },
    ).catchError(
      (onError) {
        emit(SocialUploadCoverImageError());
      },
    );
  }

  File? postImage;

  Future<void> getPostImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      postImage = File(pickedFile.path);
      emit(SocialCreatePostImageSuccess());
    } else {
      debugPrint('No image selected');
      emit(SocialCreatePostImageError());
    }
  }

  void createPostWithImage({required String dateTime, required String text}) {
    emit(SocialCreatePostWithImageLoading());
    firebase_storage.FirebaseStorage.instance
        .ref()
        .child('posts/${Uri.file(postImage!.path).pathSegments.last}')
        .putFile(postImage!)
        .then((onValue) {
      onValue.ref.getDownloadURL().then(
        (onValue) {
          createPost(
            postImage: onValue,
            dateTime: dateTime,
            text: text,
          );
          emit(SocialCreatePostWithImageSuccess());
        },
      ).catchError(
        (onError) {
          emit(SocialCreatePostWithImageError());
        },
      );
    }).catchError((onError) {
      emit(SocialCreatePostWithImageError());
    });
  }

  void createPost({
    required String dateTime,
    required String text,
    String? postImage,
  }) {
    emit(SocialCreatePostLoading());
    PostModel postModel = PostModel(
      name: userModel!.name,
      uId: userModel!.uId,
      image: userModel!.image,
      text: text,
      dateTime: dateTime,
      postImage: postImage ?? '',
    );
    FirebaseFirestore.instance
        .collection('posts')
        .add(postModel.toMap())
        .then((onValue) {
      emit(SocialCreatePostSuccess());
    }).catchError((onError) {
      emit(SocialCreatePostError());
    });
  }

  void deleteImage() {
    postImage = null;
    emit(SocialCreatePostWithImageDelete());
  }

  List<PostModel> posts = [];
  List<String> postsId = [];
  List<int> likes = [];

  Future<void> getUserPosts() async {
    emit(SocialGetUserPostsLoading());
    try {
      posts = [];
      final postsSnapshot =
          await FirebaseFirestore.instance.collection('posts').get();
      for (var element in postsSnapshot.docs) {
        final likesSnapshot = await element.reference.collection('likes').get();
        likes.add(likesSnapshot.docs.length); // get the number of likes for each post
        postsId.add(element.id);
        posts.add(PostModel.fromJson(element.data()));
      }
      emit(SocialGetUserPostsSuccess());
    } catch (onError) {
      emit(SocialGetUserPostsError());
    }
  }

  void likePost(String? postId) {
    emit(SocialCreateLikePostLoading());
    FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userModel!.uId)
        .set({'like': true}).then((onValue) {
      emit(SocialCreateLikePostSuccess());
    }).catchError(
      (onError) {
        emit(SocialCreateLikePostDelete());
      },
    );
  }

  List<UserModel> allUsers = [];

  Future<void> getAllUsers() async {
    if (allUsers.isEmpty) {
      emit(SocialGetAllUserDataLoading());
      final snapShot =
          await FirebaseFirestore.instance.collection('users').get();
      try {
        for (var item in snapShot.docs) {
          if (UserModel.fromJson(item.data()).uId != token) {
            allUsers.add(UserModel.fromJson(item.data()));
          }
        }
        emit(SocialGetAllUserDataSuccess());
      } catch (error) {
        debugPrint(error.toString());
        emit(SocialGetAllUserDataError());
      }
    }
  }

  Future<void> signOut(context) async {
    emit(SocialSignOutLoading());
    await FirebaseAuth.instance.signOut().then((onValue) {
      emit(SocialSignOutSuccess());
    }).catchError((onError) {
      emit(SocialSignOutError());
    });
  }

  void sendMessage({
    required String receiverId,
    required String text,
    required String dateTime,
  }) {
    MessageModel messageModel = MessageModel(
      dateTime: dateTime,
      text: text,
      receiverId: receiverId,
      senderId: userModel!.uId,
    );
    FirebaseFirestore.instance
        .collection('users')
        .doc(userModel!.uId)
        .collection('chat')
        .doc(receiverId)
        .collection('messages')
        .add(messageModel.toMap())
        .then((onValue) {
      emit(SocialSendMessageSuccess());
    }).catchError((onError) {
      emit(SocialSendMessageError());
    });

    FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .collection('chat')
        .doc(userModel!.uId)
        .collection('messages')
        .add(messageModel.toMap())
        .then((onValue) {
      emit(SocialSendMessageSuccess());
    }).catchError((onError) {
      emit(SocialSendMessageError());
    });
  }

  List<MessageModel> messages = [];

  void getMessages(String receiverId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userModel!.uId)
        .collection('chat')
        .doc(receiverId)
        .collection('messages')
        .orderBy('dateTime')
        .snapshots()
        .listen(
      (onData) {
        messages = [];
        for (var item in onData.docs) {
          messages.add(MessageModel.fromJson(item.data()));
        }
        emit(SocialGetMessageSuccess());
      },
    );
  }
}
