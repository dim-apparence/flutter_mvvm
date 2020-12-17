import 'package:flutter/material.dart';
import 'presenter_builder.dart';
import 'component_animated_builder.dart';
import 'mvvm_context.dart';
import 'mvvm_model.dart';

/// builds a child for a [MVVMContent]
typedef MvvmContentBuilder<P extends Presenter, M extends MVVMModel> = Widget
    Function(MvvmContext context, P presenter, M model);

/// functions to handle animation state without refresh page
typedef MvvmAnimationListener<P extends Presenter, M extends MVVMModel> = void
    Function(MvvmContext context, P presenter, M model);

/// builds a single [AnimationController]
typedef MvvmAnimationControllerBuilder = AnimationController Function(
    TickerProvider tickerProvider);

/// builds a list of [AnimationController]
typedef MvvmAnimationsControllerBuilder = List<AnimationController> Function(
    TickerProvider tickerProvider);

/// builds a presenter
typedef PresenterBuilder<P extends Presenter> = P Function(
    BuildContext context);

/// Creates a static cached page from a builder method
///
/// Prefer use this to keep presenter state from unwanted rebuild
///
/// This widget supports either zero, one, or multiple animation controllers
/// * For none, **DO NOT** pass a value in animListener,
///   singleAnimControllerBuilder and multipleAnimControllerBuilder
/// * For one, **DO** pass a value in animListener and
///   singleAnimControllerBuilder, **BUT NOT** in multipleAnimControllerBuilder
/// * For multiple, **DO** pass a value in animListener and
///   multipleAnimControllerBuilder, **BUT NOT** in singleAnimControllerBuilder
class MVVMPageBuilder<P extends Presenter, M extends MVVMModel> {
  P _presenter;

  Widget build({
    Key key,
    @required BuildContext context,
    @required PresenterBuilder presenterBuilder,
    @required MvvmContentBuilder<P, M> builder,
    MvvmAnimationListener<P, M> animListener,
    MvvmAnimationControllerBuilder singleAnimControllerBuilder,
    MvvmAnimationsControllerBuilder multipleAnimControllerBuilder,
    bool forceRebuild = false,
  }) {
    assert(context != null, 'Missing context in PageBuilder');
    assert(presenterBuilder != null, 'Missing presenterBuilder in PageBuilder');
    assert(builder != null, 'Missing builder in PageBuilder');
    assert(
        ((singleAnimControllerBuilder != null ||
                    multipleAnimControllerBuilder != null) &&
                animListener != null) ||
            (singleAnimControllerBuilder == null &&
                multipleAnimControllerBuilder == null),
        'An Animated page was requested, but no listener was given.');
    assert(
        !(singleAnimControllerBuilder != null &&
            multipleAnimControllerBuilder != null),
        'Cannot have both a single and a multiple animation controller builder.');
    if (_presenter == null || forceRebuild) {
      _presenter = presenterBuilder(context);
    }

    Widget content;

    if (multipleAnimControllerBuilder != null) {
      content = MultipleAnimatedMvvmContent<P, M>(
          multipleAnimController: multipleAnimControllerBuilder,
          animListener: animListener);
    } else if (singleAnimControllerBuilder != null) {
      content = AnimatedMvvmContent<P, M>(
          singleAnimController: singleAnimControllerBuilder,
          animListener: animListener);
    } else {
      content = MVVMContent<P, M>();
    }

    return PresenterInherited<P, M>(
      key: key,
      presenter: _presenter,
      builder: builder,
      child: content,
    );
  }

  @visibleForTesting
  P get presenter => _presenter;
}

/// Creates a new MVVM widget to split business logic easily from rendering
///
/// This widget supports either zero, one, or multiple animation controllers
/// * For none, **DO NOT** pass a value in animListener,
///   singleAnimControllerBuilder and multipleAnimControllerBuilder
/// * For one, **DO** pass a value in animListener and
///   singleAnimControllerBuilder, **BUT NOT** in multipleAnimControllerBuilder
/// * For multiple, **DO** pass a value in animListener and
///   multipleAnimControllerBuilder, **BUT NOT** in singleAnimControllerBuilder
class MVVMPage<P extends Presenter, M extends MVVMModel>
    extends StatelessWidget {
  final P _presenter;
  final MvvmContentBuilder<P, M> _builder;
  final MvvmAnimationListener<P, M> _animListener;
  final MvvmAnimationControllerBuilder _singleAnimControllerBuilder;
  final MvvmAnimationsControllerBuilder _multipleAnimControllerBuilder;

  const MVVMPage({
    Key key,
    @required P presenter,
    @required MvvmContentBuilder<P, M> builder,
    MvvmAnimationListener<P, M> animListener,
    MvvmAnimationControllerBuilder singleAnimControllerBuilder,
    MvvmAnimationsControllerBuilder multipleAnimControllerBuilder,
  })  : assert(presenter != null, 'Missing presenter in page'),
        this._presenter = presenter,
        assert(builder != null, 'Missing builder in Page'),
        this._builder = builder,
        assert(
            ((singleAnimControllerBuilder != null ||
                        multipleAnimControllerBuilder != null) &&
                    animListener != null) ||
                (singleAnimControllerBuilder == null &&
                    multipleAnimControllerBuilder == null),
            'An Animated page was requested, but no listener was given.'),
        this._animListener = animListener,
        assert(
            !(singleAnimControllerBuilder != null &&
                multipleAnimControllerBuilder != null),
            'Cannot have both a single and a multiple animation controller builder.'),
        this._singleAnimControllerBuilder = singleAnimControllerBuilder,
        this._multipleAnimControllerBuilder = multipleAnimControllerBuilder,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_multipleAnimControllerBuilder != null) {
      content = MultipleAnimatedMvvmContent<P, M>(
          multipleAnimController: _multipleAnimControllerBuilder,
          animListener: _animListener);
    } else if (_singleAnimControllerBuilder != null) {
      content = AnimatedMvvmContent<P, M>(
          singleAnimController: _singleAnimControllerBuilder,
          animListener: _animListener);
    } else {
      content = MVVMContent<P, M>();
    }

    return PresenterInherited<P, M>(
      presenter: _presenter,
      builder: _builder,
      child: content,
    );
  }

  @visibleForTesting
  P get presenter => _presenter;
}

/// Base class for views to implement
abstract class MVVMView {
  /// force to refresh all view
  void forceRefreshView();

  /// calls refresh animation state
  Future<void> refreshAnimation();

  /// calls stop & dispose for each animation(s)
  Future<void> disposeAnimation();
}

class MVVMContent<P extends Presenter, M extends MVVMModel>
    extends StatefulWidget {
  const MVVMContent({Key key}) : super(key: key);

  @override
  State<MVVMContent> createState() => _MVVMContentState<P, M>();
}

class _MVVMContentState<P extends Presenter, M extends MVVMModel>
    extends State<MVVMContent> implements MVVMView {
  bool hasInit = false;

  _MVVMContentState() {
    print("_MVVMContentState");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(presenter != null, "Presenter must be not null");
    presenter.view = this;
    if (!hasInit) {
      hasInit = true;
      presenter.onInit();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context != null) {
          presenter.afterViewInit();
        }
      });
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    hasInit = false;
  }

  @override
  void deactivate() {
    presenter.onDestroy();
    super.deactivate();
    presenter.afterViewDestroyed();
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      builder(mvvmContext, presenter, presenter.viewModel);

  @override
  void forceRefreshView() {
    if (mounted) {
      setState(() {});
    }
  }

  MvvmContext get mvvmContext => MvvmContext(context);

  P get presenter => PresenterInherited.of<P, M>(context).presenter;

  MvvmContentBuilder<P, M> get builder =>
      PresenterInherited.of<P, M>(context).builder;

  @override
  Future<void> refreshAnimation() => throw UnimplementedError();

  @override
  Future<void> disposeAnimation() => throw UnimplementedError();
}
