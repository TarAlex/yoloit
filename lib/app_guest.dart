import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/collaboration/bloc/collaboration_cubit.dart';
import 'features/collaboration/ui/guest_shell.dart';
import 'features/mindmap/bloc/mindmap_cubit.dart';

/// Minimal app for web / non-desktop platforms.
/// Only MindMapCubit + CollaborationCubit — no native platform code.
class GuestApp extends StatelessWidget {
  const GuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MindMapCubit()),
        BlocProvider(
          create: (ctx) => CollaborationCubit(
            mindMapCubit: ctx.read<MindMapCubit>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'YoLoIT Space',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF070714),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4B9EFF),
            secondary: Color(0xFF00FF9F),
            surface: Color(0xFF0D1117),
          ),
          fontFamily: 'monospace',
        ),
        home: const GuestShell(),
      ),
    );
  }
}
