/*
 * 鸿蒙侧唯一的 ArkUI 页面，只负责宿主 FlutterPage。
 *
 * 音量键翻页不在 ArkUI 层做：音量键在分发到应用前就被系统消费，
 * FlutterPage 的 onKeyEvent 收不到。改由 KiraVolumeChannel 走
 * Input Kit 的 inputConsumer.on('keyPressed')「优先响应系统功能键」订阅，
 * 见 plugins/KiraVolumeChannel.ets。
 *
 * 返回键沿用框架既有链路：这里只 emit EVENT_BACK_PRESS，
 * FlutterView.onBackPressCallback 会调 NavigationChannel.popRoute()
 * （键盘弹起时先收键盘）。不要自己 popRoute，会与框架回调重复。
 */
import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  build() {
    Column() {
      FlutterPage({ viewId: this.viewId })
    }
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
