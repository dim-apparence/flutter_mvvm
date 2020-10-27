import 'package:flutter/material.dart';
import 'component_builder.dart';
import 'mvvm_model.dart';

/// Wraps presenter inside a persistent Widget
class PresenterInherited<T extends Presenter, M extends MVVMModel>
    extends InheritedWidget {
  /// Presenter coupled to the view built by builder
  final T presenter;

  /// Method used to build the view corresponding to the presenter
  final MvvmContentBuilder<T, M> builder;

  /// Wraps presenter inside a persistent Widget
  const PresenterInherited({
    Key key,
    this.presenter,
    Widget child,
    this.builder,
  }) : super(key: key, child: child);

  /// Find the closest PresenterInherited above the current widget
  static PresenterInherited<T, M> of<T extends Presenter, M extends MVVMModel>(
    BuildContext context,
  ) =>
      context.dependOnInheritedWidgetOfExactType<PresenterInherited<T, M>>();

  @override
  bool updateShouldNotify(PresenterInherited oldWidget) => true;
}

/// This class must be overriden too
abstract class Presenter<T extends MVVMModel, I> {
  MVVMView _view;

  /// Interface defining the exposed methods of the view
  I viewInterface;

  /// Model containing the current state of the view
  T viewModel;

  /// Container controlling the current state of the view
  Presenter(this.viewModel, this.viewInterface);

  /// called when view init
  void onInit() {}

  /// called when view has been drawn for the 1st time
  void afterViewInit() {}

  /// called when view is destroyed
  void onDestroy() {}

  /// set the view reference to presenter
  set view(MVVMView view) => _view = view;

  /// call this to refresh the view
  /// if you mock [I] this will have no effect when calling forceRefreshView
  void refreshView() => _view?.forceRefreshView();

  /// call this to refresh animations
  /// this will start animations from your animation listener of MvvmBuilder
  Future<void> refreshAnimations() async => _view?.refreshAnimation();

  /// call this to dispose animations
  /// this will stop & dispose all animations
  Future<void> disposeAnimations() async => _view?.disposeAnimation();
}
